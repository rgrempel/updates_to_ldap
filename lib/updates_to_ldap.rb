require 'ldap'
require 'active_record'
require 'hmac-sha1'

module UpdatesToLDAP
  def self.append_features(base)
    super
    base.extend(ClassMethods)
  end

  module ClassMethods
    def updates_to_ldap
      class_eval do
        extend UpdatesToLDAP::SingletonMethods

        after_create :ldap_create
        after_update :ldap_update
        after_destroy :ldap_destroy
      end
      include UpdatesToLDAP::InstanceMethods
    end

    def authenticates_to_ldap
      include UpdatesToLDAP::InstanceMethods
    end
  end

  module SingletonMethods
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
    @@ldapconn ||= LDAP::Conn.new
    @@ldap_root_dn = ""
    @@ldap_bind_dn = ""
    @@ldap_bind_pw = ""

    unless @@ldapconn.bound?
      @@ldapconn.set_option( LDAP::LDAP_OPT_PROTOCOL_VERSION, 3 )
      yml = YAML::load_file "#{RAILS_ROOT}/config/ldap.yml"
      @@ldap_root_dn = yml[RAILS_ENV]['rootdn']
      @@ldap_bind_dn = yml[RAILS_ENV]['binddn']
      @@ldap_bind_pw = yml[RAILS_ENV]['password']
      @@ldapconn.bind @@ldap_bind_dn, @@ldap_bind_pw
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
      "#{dn},#{@@ldap_root_dn}"
    end

    def ldap_create
      begin
        @@ldapconn.add ldap_dn, to_ldap_hash.delete_if {|k, v| v.empty?}
      rescue LDAP::ResultError => e
        raise e
        ldap_update
      end
      true
    end

    def ldap_update
      begin
        @@ldapconn.modify ldap_dn, to_ldap_hash
      rescue LDAP::ResultError => e
        raise e unless e.message == "No such object"
        ldap_create
      end
      true
    end

    def ldap_destroy
      begin
        @@ldapconn.delete ldap_dn
      rescue LDAP::ResultError => e
        raise e unless e.message == "No such object"
      end
      true
    end

    def get_ldap_password
      result = @@ldapconn.search2 ldap_dn, LDAP::LDAP_SCOPE_BASE, 'objectClass=*', ['userPassword']
      return "" if result.size == 0
      return "" unless result[0]['userPassword']
      result[0]['userPassword'][0]
    end

    def ldap_update_password (password)
      system "/usr/local/bin/ldappasswd", "-x", "-D", @@ldap_bind_dn, "-w", @@ldap_bind_pw, "-s", password, ldap_dn
    end

    def get_ldap_hash
      result = @@ldapconn.search2 ldap_dn, LDAP::LDAP_SCOPE_BASE, 'objectClass=*'
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
end

ActiveRecord::Base.class_eval do
  include UpdatesToLDAP
end
