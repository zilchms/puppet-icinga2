require 'spec_helper'

describe('icinga2::feature::api', :type => :class) do
  let(:pre_condition) {[
    "class { 'icinga2': features => [], constants => {'NodeName' => 'host.example.org'} }" ]}


  on_supported_os.each do |os, facts|
    context "on #{os}" do

      let(:facts) do
        case facts[:kernel]
        when 'windows'
          facts.merge({
            :icinga2_puppet_hostcert => 'C:/ProgramData/PuppetLabs/puppet/ssl/certs/host.example.org.pem',
            :icinga2_puppet_hostprivkey => 'C:/ProgramData/PuppetLabs/puppet/ssl/private_keys/host.example.org.pem',
            :icinga2_puppet_localcacert => 'C:/ProgramData/PuppetLabs/var/lib/puppet/ssl/certs/ca.pem',
          })
        else
          facts.merge({
            :icinga2_puppet_hostcert => '/etc/puppetlabs/puppet/ssl/certs/host.example.org.pem',
            :icinga2_puppet_hostprivkey => '/etc/puppetlabs/puppet/ssl/private_keys/host.example.org.pem',
            :icinga2_puppet_localcacert => '/etc/lib/puppetlabs/puppet/ssl/certs/ca.pem',
          })
        end
      end

      before(:each) do
        case facts[:kernel]
        when 'windows'
          @icinga2_bin_dir = 'C:/Program Files/icinga2/sbin'
          @icinga2_bin = 'icinga2.exe'
          @icinga2_conf_dir = 'C:/ProgramData/icinga2/etc/icinga2'
          @icinga2_pki_dir = 'C:/ProgramData/icinga2/var/lib/icinga2/certs'
          @icinga2_sslkey_mode = nil
          @icinga2_user = nil
          @icinga2_group = nil
        when 'FreeBSD'
          @icinga2_bin_dir = '/usr/local/sbin'
          @icinga2_bin = 'icinga2'
          @icinga2_conf_dir = '/usr/local/etc/icinga2'
          @icinga2_pki_dir = '/var/lib/icinga2/certs'
          @icinga2_sslkey_mode = '0600'
          @icinga2_user = 'icinga'
          @icinga2_group = 'icinga'
        else
          @icinga2_bin = 'icinga2'
          @icinga2_conf_dir = '/etc/icinga2'
          @icinga2_pki_dir = '/var/lib/icinga2/certs'
          @icinga2_sslkey_mode = '0600'
          case facts[:osfamily]
          when 'Debian'
            @icinga2_user = 'nagios'
            @icinga2_group = 'nagios'
            @icinga2_bin_dir = '/usr/sbin'
          else
            @icinga2_user = 'icinga'
            @icinga2_group = 'icinga'
            if facts[:osfamily] != 'RedHat'
              @icinga2_bin_dir = '/usr/sbin'
            else
              case facts[:operatingsystemmajrelease]
              when '5'
                @icinga2_bin_dir = '/usr/sbin'
              when '6'
                @icinga2_bin_dir = '/usr/sbin'
              else
                @icinga2_bin_dir = '/sbin'
              end
            end
          end
        end
      end

      context "with all defaults" do
        it { is_expected.to contain_icinga2__feature('api').with({
          'ensure' => 'present',
        }) }

        it { is_expected.to contain_icinga2__object('icinga2::object::ApiListener::api')
          .with({ 'target' => "#{@icinga2_conf_dir}/features-available/api.conf" })
          .that_notifies('Class[icinga2::service]') }

        it { is_expected.to contain_file("#{@icinga2_pki_dir}/host.example.org.key")
         .with({
            'ensure' => 'file',
            'owner'  => @icinga2_user,
            'group'  => @icinga2_group,
            'mode'   => @icinga2_sslkey_mode, }) }

        it { is_expected.to contain_file("#{@icinga2_pki_dir}/host.example.org.crt")
         .with({
            'ensure' => 'file',
            'owner'  => @icinga2_user,
            'group'  => @icinga2_group, }) }

        it { is_expected.to contain_file("#{@icinga2_pki_dir}/ca.crt")
         .with({
            'ensure' => 'file',
            'owner'  => @icinga2_user,
            'group'  => @icinga2_group, }) }

        it { is_expected.to contain_icinga2__object__endpoint('NodeName') }

        it { is_expected.to contain_icinga2__object__zone('ZoneName')
          .with({ 'endpoints' => [ 'NodeName' ] }) }
      end

      context "with ensure => absent" do
        let(:params) { {:ensure => 'absent'} }

        it { is_expected.to contain_icinga2__feature('api').with({
          'ensure' => 'absent', }) }
      end

      context "with pki => 'none', ssl_key => 'foo', ssl_cert => 'bar', ssl_cacert => 'baz'" do
        let(:params) { {:pki => 'none', 'ssl_key' => 'foo', 'ssl_cert' => 'bar', 'ssl_cacert' => 'baz'} }

        it { is_expected.to contain_file("#{@icinga2_pki_dir}/host.example.org.key")
          .with({
            'ensure' => 'file',
            'owner'  => @icinga2_user,
            'group'  => @icinga2_group,
            'mode'   => @icinga2_sslkey_mode, })
          .with_content(/^foo$/) }

        it { is_expected.to contain_file("#{@icinga2_pki_dir}/host.example.org.crt")
         .with({
            'ensure' => 'file',
            'owner'  => @icinga2_user,
            'group'  => @icinga2_group, })
          .with_content(/^bar$/) }

        it { is_expected.to contain_file("#{@icinga2_pki_dir}/ca.crt")
         .with({
            'ensure' => 'file',
            'owner'  => @icinga2_user,
            'group'  => @icinga2_group, })
          .with_content(/^baz$/) }
      end

      context "with pki => 'icinga2', ca_host => 'foo', ca_port => 1234, ticket_salt => 'bar'" do
        let(:params) { {:pki => 'icinga2', :ca_host => 'foo', :ca_port => 1234, :ticket_salt => 'bar'} }

        it { is_expected.to contain_exec('icinga2 pki create key')
          .with({
            'path'    => @icinga2_bin_dir,
            'command' => "#{@icinga2_bin} pki new-cert --cn host.example.org --key #{@icinga2_pki_dir}/host.example.org.key --cert #{@icinga2_pki_dir}/host.example.org.crt",
            'creates' => "#{@icinga2_pki_dir}/host.example.org.key", })
          .that_notifies('Class[icinga2::service]') }

        it { is_expected.to contain_exec('icinga2 pki get trusted-cert')
          .with({
            'path'    => @icinga2_bin_dir,
            'command' => "#{@icinga2_bin} pki save-cert --host foo --port 1234 --key #{@icinga2_pki_dir}/host.example.org.key --cert #{@icinga2_pki_dir}/host.example.org.crt --trustedcert #{@icinga2_pki_dir}/trusted-cert.crt",
            'creates' => "#{@icinga2_pki_dir}/trusted-cert.crt", })
          .that_notifies('Class[icinga2::service]') }

        it { is_expected.to contain_exec('icinga2 pki request')
          .with({
            'path'    => @icinga2_bin_dir,
            'command' => "#{@icinga2_bin} pki request --host foo --port 1234 --ca #{@icinga2_pki_dir}/ca.crt --key #{@icinga2_pki_dir}/host.example.org.key --cert #{@icinga2_pki_dir}/host.example.org.crt --trustedcert #{@icinga2_pki_dir}/trusted-cert.crt --ticket ac5cb0d8c98f3f50ceff399b3cfedbb03782c117",
            'creates' => "#{@icinga2_pki_dir}/ca.crt", })
          .that_notifies('Class[icinga2::service]') }
      end

    end
  end
end
