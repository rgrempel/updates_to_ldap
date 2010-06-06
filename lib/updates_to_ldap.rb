require 'ldap'
require 'hmac-sha1'
require 'active_model'
require 'rails'

module UpdatesToLDAP
  class Railtie < Rails::Railtie
    config.updates_to_ldap = ActiveSupport::OrderedOptions.new

    initializer :updates_to_ldap_establish_connection do
      config = Rails.root.join("config", "updates_to_ldap.yml")
      if File.exist? config
        spec = YAML::load_file(config)[Rails.env].symbolize_keys
        ActiveRecord::Base.establish_ldap_connection spec
      end
    end
  end

  module ClassMethods
    def ldap_connection
      self.ldap_spec[:connection]
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

  def authenticate_with_challenge password, challenge
    password == HMAC::SHA1::hexdigest( get_ldap_hash["userPassword"][0], challenge )
  end

  def authenticate (password, challenge="")
    return authenticate_with_challenge(password, challenge) unless challenge.empty?
    return false if password.blank?
    begin
      conn = LDAP::Conn.new
      conn.set_option LDAP::LDAP_OPT_PROTOCOL_VERSION, 3
      conn.bind ldap_dn, password
      retval = true
    rescue => e
      retval = false
    ensure
      conn.unbind if conn
      conn = nil
    end
    retval
  end

  def ldap_dn
    "#{dn},#{self.ldap_spec[:root_dn]}"
  end

  def ldap_create
    return
    begin
      self.class.ldap_connection.add ldap_dn, to_ldap_hash.delete_if {|k, v| v.empty?}
    rescue LDAP::ResultError => e
      raise e
      ldap_update
    end
    true
  end

  def ldap_update
    return
    begin
      self.class.ldap_connection.ldapconn.modify ldap_dn, to_ldap_hash
    rescue LDAP::ResultError => e
      raise e unless e.message == "No such object"
      ldap_create
    end
    true
  end

  def ldap_destroy
    return
    begin
      self.class.ldap_connection.ldapconn.delete ldap_dn
    rescue LDAP::ResultError => e
      raise e unless e.message == "No such object"
    end
    true
  end

  def get_ldap_password
    result = self.class.ldap_connection.search2 ldap_dn, LDAP::LDAP_SCOPE_BASE, 'objectClass=*', ['userPassword']
    return "" if result.size == 0
    return "" unless result[0]['userPassword']
    result[0]['userPassword'][0]
  end

  def ldap_update_password (password)
    system "/usr/local/bin/ldappasswd", "-x", "-D", self.class.ldap_spec[:bind_dn], "-w", self.class.ldap_spec[:bind_pw], "-s", password, ldap_dn
  end

  def get_ldap_hash
    result = self.class.ldap_connection.search2 ldap_dn, LDAP::LDAP_SCOPE_BASE, 'objectClass=*'
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

  def to_ldap
    LDAP.hash2mods LDAP::LDAP_MOD_REPLACE, to_ldap_hash
  end

  def to_ldif
    LDAP::LDIF.mods_to_ldif ldap_dn, to_ldap
  end
end

class ActiveRecord::Base
  class_inheritable_accessor :ldap_spec
  
  def self.authenticates_to_ldap
    include UpdatesToLDAP
    extend UpdatesToLDAP::ClassMethods
  end

  def self.updates_to_ldap
    authenticates_to_ldap

    after_create  :ldap_create
    after_update  :ldap_update
    after_destroy :ldap_destroy
  end
    
  def self.establish_ldap_connection spec
    if spec
      if spec.class == Symbol
        
      end

      self.ldap_spec = {
        :host => 'localhost',
        :port => 389
      }.merge(spec.symbolize_keys)
    end
    
    self.ldap_spec[:connection] = LDAP::Conn.new self.ldap_spec[:host], self.ldap_spec[:port]
    self.ldap_spec[:connection].set_option LDAP::LDAP_OPT_PROTOCOL_VERSION, 3
    self.ldap_spec[:connection].bind self.ldap_spec[:bind_dn], self.ldap_spec[:bind_pw]
  end
end
