require 'net/ldap'
require 'hmac-sha1'
require 'active_model'
require 'rails'

class Hash
  def ldap_merge hsh
    merge hsh do |key, oldvalue, newvalue|
      [oldvalue].concat([newvalue]).flatten
    end
  end
end

module Net
  class LDAP
    class ServerError < RuntimeError
      attr_reader :operation_result

      def initialize result
        @operation_result = result
        super
      end

      def to_s
        @operation_result.inspect
      end
    end

    def exception
      ServerError.new get_operation_result
    end

    def nested_open
      if @open_connection
        yield self
      else
        open do |ldap|
          yield ldap
        end
      end
    end
  end
end

module UpdatesToLDAP
  # A big flag to enable/disable the callbacks. Note that this is not thread-safe,
  # so it really is only for limited purposes ... for instance, if you are testing
  # and you don't want the overhead of saving to LDAP.
  mattr_accessor :enabled
  self.enabled = true

  class Railtie < Rails::Railtie
    initializer :updates_to_ldap_establish_connection do
      # We load a default configuration in ActiveRecord::Base
      file = Rails.root.join("config", "updates_to_ldap.yml")
      if File.exist?(file)
        config.updates_to_ldap_spec = YAML::load_file(file)[Rails.env].symbolize_keys
      else
        config.updates_to_ldap_spec = {}
      end
    end
  end

  module ClassMethods
    def setup_updates_to_ldap_options options={}
      options[:ldap_spec] ||= {}
      options[:if] ||= []

      class_inheritable_accessor :updates_to_ldap_options
      superclass_options = self.updates_to_ldap_options || {}
      superclass_options[:ldap_spec] ||= {}
      superclass_options[:if] ||= []

      self.updates_to_ldap_options = {}
      self.updates_to_ldap_options[:ldap_spec] = {
        :host => 'localhost',
        :port => 389
      }.merge(UpdatesToLDAP::Railtie.config.updates_to_ldap_spec).
        merge(superclass_options[:ldap_spec]).
        merge(options[:ldap_spec].symbolize_keys)

      self.updates_to_ldap_options[:if] = superclass_options[:if].dup.concat [options[:if]].flatten.compact
    end

    # Return an ldap connection. We construct it lazily, per-class, and
    # make it thread-local.
    def ldap_connection
      key = "__#{self}__ldap_connection".to_sym
      Thread.current[key] = Net::LDAP.new(self.updates_to_ldap_options[:ldap_spec]) unless Thread.current[key]
      Thread.current[key]
    end

    # Deletes the ldap_base ... mostly for fixtures ... you
    # generally don't want to do this!
    def delete_ldap_base
      return unless UpdatesToLDAP.enabled
      self.ldap_connection.nested_open do |ldap|
        entries = ldap.search(
          :base => self.updates_to_ldap_options[:ldap_spec][:root_dn],
          :scope => Net::LDAP::SearchScope_WholeSubtree,
          :filter => "objectClass=*",
          :attributes => ["objectClass"],
          :return_results => true
        )
        # We sort them so that we delete children before parents
        if entries
          entries.sort! {|a, b| b.dn.length <=> a.dn.length}
          entries.each do |entry|
            ldap.delete :dn => entry.dn
          end
        end
      end
    end

    # Load an ldif file. This is mostly for fixtures for testing ... we
    # assume that you're populating your real LDAP server differently.
    # We ignore errors for records that already exist, assuming that you
    # just haven't deleted your fixtures.
    def process_ldif file
      return unless UpdatesToLDAP.enabled
      self.ldap_connection.nested_open do |ldap|
        File.open(file) do |f|
          Net::LDAP::Dataset.read_ldif(f).each_pair do |dn, attributes|
            ldap.add :dn => dn, :attributes => attributes
            # 68 is record already exists
            raise ldap unless [0, 68].include?(ldap.get_operation_result.code)
          end
        end
      end
    end

    # Compares the existing ldap to what we would produce
    def check_ldap(each_line = false)
      return unless UpdatesToLDAP.enabled
      find(:all).each do |m|
        print "#{m.dn}\n" if each_line
        diff = m.get_ldap_diff
        print "#{m.dn}\n --> " + diff.join(" -- ") + "\n\n" unless diff.empty?
      end
      nil
    end
  end

  module InstanceMethods
    # Authenticate with a challenge that was supplied to the user
    def authenticate_with_challenge password, challenge
      password == HMAC::SHA1::hexdigest( get_ldap_hash["userPassword"][0], challenge )
    end

    # Authenticate by binding, or with challenge if supplied
    def authenticate (password, challenge="")
      return authenticate_with_challenge(password, challenge) unless challenge.empty?
      return false if password.blank?
      self.class.ldap_connection.bind :method => :simple,
                                      :username => ldap_dn,
                                      :password => password
    end

    def ldap_dn
      "#{dn},#{self.updates_to_ldap_options[:ldap_spec][:base]}"
    end

    def ldap_apply_conditions
      self.class.updates_to_ldap_options[:if].all? {|p| self.send p}
    end

    # Whether the ldap record exists
    def ldap_exists?
      self.class.ldap_connection.search(
        :base => ldap_dn,
        :scope => Net::LDAP::SearchScope_BaseObject,
        :filter => 'objectClass=*'
      ) ? true : false
    end

    # The callback when records are created
    def ldap_create
      return unless UpdatesToLDAP.enabled
      return unless ldap_apply_conditions
      # We delete nil values or empty arrays because that is how we indicate that something is not present
      attributes = to_ldap_hash.delete_if {|key, value| value.nil? || value == [] || value == [nil]}
      self.class.ldap_connection.nested_open do |ldap|
        ldap.add :dn => ldap_dn, :attributes => attributes
        return ldap_update if ldap.get_operation_result.code == 68 # record already exists, so update
        raise ldap unless ldap.get_operation_result.code == 0
      end
    end

    # Callback when records are updated
    def ldap_update
      return unless UpdatesToLDAP.enabled
      if ldap_apply_conditions
        self.class.ldap_connection.nested_open do |ldap|
          to_ldap_hash.each_pair do |key, value|
            ldap.replace_attribute ldap_dn, key, value
            case ldap.get_operation_result.code
              when 32 # entry does not exist
                return ldap_create
              when 69 # cannot change structural superclass
                ldap_destroy
                return ldap_create
              when 0 # do nothing
              else raise ldap
            end
          end
        end
      else
        ldap_destroy
      end
    end

    # Callback when records are deleted
    def ldap_destroy
      return unless UpdatesToLDAP.enabled
      self.class.ldap_connection.nested_open do |ldap|
        ldap.delete :dn => ldap_dn
        raise ldap unless [0, 32].include?(ldap.get_operation_result.code) # 32 is that it does not exist
      end
    end

    # Gets userPassword from ldap
    def ldap_password
      return unless UpdatesToLDAP.enabled
      result = self.class.ldap_connection.search(
        :base => ldap_dn,
        :scope => Net::LDAP::SearchScope_BaseObject,
        :filter => 'objectClass=*',
        :attributes => ['userPassword']
      )
      return "" if result.size == 0
      return "" unless result[0]['userPassword']
      result[0]['userPassword'][0]
    end

    # Sets the userPassword. Note that at present you must save the record itself first, since
    # this will not create the LDAP entry.
    def ldap_password= password
      return unless UpdatesToLDAP.enabled
      spec = self.class.updates_to_ldap_options[:ldap_spec]
      system "/usr/bin/ldappasswd", "-x",
                                    "-h", spec[:host],
                                    "-p", spec[:port].to_s,
                                    "-D", spec[:auth][:username],
                                    "-w", spec[:auth][:password],
                                    "-s", password,
                                    ldap_dn
    end

    # Returns our ldap entry as a hash
    def get_ldap_hash
      return unless UpdatesToLDAP.enabled
      result = self.class.ldap_connection.search(
        :base => ldap_dn,
        :scope => Net::LDAP::SearchScope_BaseObject,
        :filter => 'objectClass=*'
      )
      result[0]
    end

    def get_ldap_diff
      retval = []

      database = to_ldap_hash
      ldap = get_ldap_hash

      database.each_pair do |key, value|
        if ldap.has_key? key
          ldapvalue = ldap[key]

          if ['uniqueMember','objectClass'].include? key
            value.sort!
            ldapvalue.sort!
          end

          if key == "objectClass"
            value.delete "top"
            %w( top sambaGroupMapping ).each {|v| ldapvalue.delete v}
          end

          next if ['owner','sambaGroupType', 'loginShell'].include? key
          retval << "#{key} database => #{value.inspect} ldap => #{ldapvalue.inspect}" unless value == ldapvalue
        else
          retval << "#{key} not in ldap" unless value.empty?
        end
      end

      ldap.each_pair do |key, value|
        next if ['owner','sambaGroupType', 'sambaPrimaryGroupSID', 'initials', 'userPassword', 'dn'].include? key
        retval << "#{key} not in database => #{value}" unless database.has_key? key || value.empty?
      end

      retval
    end
  end
end

class ActiveRecord::Base
  def self.authenticates_to_ldap options={}
    include UpdatesToLDAP::InstanceMethods
    extend UpdatesToLDAP::ClassMethods

    setup_updates_to_ldap_options options
  end

  def self.updates_to_ldap options={}
    authenticates_to_ldap options

    after_create  :ldap_create
    after_update  :ldap_update
    after_destroy :ldap_destroy
  end
end
