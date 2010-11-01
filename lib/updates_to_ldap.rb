require 'net/ldap'
require 'hmac-sha1'
require 'active_model'
require 'rails'

module UpdatesToLDAP
  class ServerError < RuntimeError
    attr_reader :operation_result

    def initialize ldap
      @operation_result = ldap.get_operation_result
    end

    def to_str
      @operation_result.inspect
    end
  end

  class Railtie < Rails::Railtie
    config.updates_to_ldap = ActiveSupport::OrderedOptions.new

    initializer :updates_to_ldap_establish_connection do
      # We load a default configuration in ActiveRecord::Base
      config = Rails.root.join("config", "updates_to_ldap.yml")
      if File.exist?(config)
        spec = YAML::load_file(config)[Rails.env].symbolize_keys
        ActiveRecord::Base.establish_ldap_connection spec
      end
    end
  end

  module ClassMethods
    def ldap_connection
      Net::LDAP.new self.ldap_spec
    end

    # Deletes the ldap_base ... mostly for fixtures ... you
    # generally don't want to do this!
    def delete_ldap_base
      self.ldap_connection.open do |ldap|
        entries = ldap.search(
          :base => self.ldap_spec[:root_dn],
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
      self.ldap_connection.open do |ldap|
        File.open(file) do |f|
          Net::LDAP::Dataset.read_ldif(f).each_pair do |dn, attributes|
            ldap.add :dn => dn, :attributes => attributes
            # 68 is record already exists
            raise ServerError.new(ldap) unless [0, 68].include?(ldap.get_operation_result.code)
          end
        end
      end
    end

    def check_ldap(each_line = false)
      find(:all).each do |m|
        print "#{m.dn}\n" if each_line
        diff = m.get_ldap_diff
        print "#{m.dn}\n --> " + diff.join(" -- ") + "\n\n" unless diff.empty?
      end
      nil
    end
  end

  module InstanceMethods
    def authenticate_with_challenge password, challenge
      password == HMAC::SHA1::hexdigest( get_ldap_hash["userPassword"][0], challenge )
    end

    def authenticate (password, challenge="")
      return authenticate_with_challenge(password, challenge) unless challenge.empty?
      return false if password.blank?
      ldap = self.ldap_connection
      ldap.bind :method => :simple,
                :username => ldap_dn,
                :password => password
    end

    def ldap_dn
      "#{dn},#{self.ldap_spec[:root_dn]}"
    end

    def ldap_create
      self.class.ldap_connection.add ldap_dn, to_ldap_hash.delete_if {|k, v| v.empty?}
    end

    def ldap_update
      self.class.ldap_connection.open do |ldap|
        to_ldap_hash.each_pair do |key, value|
          ldap.replace_attribute ldap_dn, key, value
        end
      end
    end

    def ldap_destroy
      self.class.ldap_connection.delete ldap_dn
    end

    def get_ldap_password
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

    def ldap_update_password (password)
      system "/usr/local/bin/ldappasswd", "-x", "-D", self.class.ldap_spec[:bind_dn], "-w", self.class.ldap_spec[:bind_pw], "-s", password, ldap_dn
    end

    def get_ldap_hash
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
  class_inheritable_accessor :ldap_spec

  def self.authenticates_to_ldap spec=nil
    establish_ldap_connection spec

    include UpdatesToLDAP::InstanceMethods
    extend UpdatesToLDAP::ClassMethods
  end

  def self.updates_to_ldap spec=nil
    authenticates_to_ldap spec

    after_create  :ldap_create
    after_update  :ldap_update
    after_destroy :ldap_destroy
  end

  def self.establish_ldap_connection spec
    if spec
      self.ldap_spec ||= {}
      self.ldap_spec = {
        :host => 'localhost',
        :port => 389
      }.merge(self.ldap_spec).merge(spec.symbolize_keys)
    end
  end
end
