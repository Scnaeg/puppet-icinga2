# @summary
#   Installs and configures the Icinga 2 feature ido-mysql.
#
# @example The ido-mysql featue requires an existing database and a user with permissions. This example uses the [puppetlabs/mysql](https://forge.puppet.com/puppetlabs/mysql) module.
#   include mysql::server
#
#   mysql::db { 'icinga2':
#     user     => 'icinga2',
#     password => 'supersecret',
#     host     => 'localhost',
#     grant    => ['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'DROP', 'CREATE VIEW', 'CREATE', 'INDEX', 'EXECUTE', 'ALTER'],
#   }
#
#   class{ 'icinga2::feature::idomysql':
#     user          => "icinga2",
#     password      => "supersecret",
#     database      => "icinga2",
#     import_schema => true,
#     require       => Mysql::Db['icinga2']
#   }
#
# @param ensure
#   Set to present enables the feature ido-mysql, absent disables it.
#
# @param host
#    MySQL database host address.
#
# @param port
#    MySQL database port.
#
# @param socket_path
#    MySQL socket path.
#
# @param user
#    MySQL database user with read/write permission to the icinga database.
#
# @param password
#    MySQL database user's password. The password parameter isn't parsed anymore.
#
# @param database
#    MySQL database name.
#
# @param enable_ssl
#   Either enable or disable SSL/TLS. Other SSL parameters are only affected if this is set to 'true'.
#
# @param ssl_key_path
#   Location of the client private key. Only valid if ssl is enabled.
#
# @param ssl_cert_path
#   Location of the client certificate. Only valid if ssl is enabled.
#
# @param ssl_cacert_path
#   Location of the CA certificate. Only valid if ssl is enabled.
#
# @param ssl_key
#   The client private key in PEM Format. Only valid if ssl is enabled.
#
# @param ssl_cert
#   The client certificate in PEM format. Only valid if ssl is enabled.
#
# @param ssl_cacert
#   The CA root certificate in PEM format. Only valid if ssl is enabled.
#
# @param ssl_capath
#    MySQL SSL trusted SSL CA certificates in PEM format directory path. Only valid if ssl is enabled.
#
# @param ssl_cipher
#    MySQL SSL list of allowed ciphers. Only valid if ssl is enabled.
#
# @param table_prefix
#   MySQL database table prefix.
#
# @param instance_name
#   Unique identifier for the local Icinga 2 instance.
#
# @param instance_description
#   Description for the Icinga 2 instance.
#
# @param enable_ha
#   Enable the high availability functionality. Only valid in a cluster setup.
#
# @param failover_timeout
#   Set the failover timeout in a HA cluster. Must not be lower than 60s.
#
# @param cleanup
#   Hash with items for historical table cleanup.
#
# @param categories
#   Array of information types that should be written to the database.
#
# @param import_schema
#   Whether to import the MySQL schema or not. New options `mariadb` and `mysql`,
#   both means true. With mariadb its cli options are used for the import,
#   whereas with mysql its different options.
#
class icinga2::feature::idomysql (
  Variant[String, Sensitive[String]]           $password,
  Enum['absent', 'present']                    $ensure                 = present,
  Stdlib::Host                                 $host                   = 'localhost',
  Optional[Stdlib::Port::Unprivileged]         $port                   = undef,
  Optional[Stdlib::Absolutepath]               $socket_path            = undef,
  String                                       $user                   = 'icinga',
  String                                       $database               = 'icinga',
  Boolean                                      $enable_ssl             = false,
  Optional[Stdlib::Absolutepath]               $ssl_key_path           = undef,
  Optional[Stdlib::Absolutepath]               $ssl_cert_path          = undef,
  Optional[Stdlib::Absolutepath]               $ssl_cacert_path        = undef,
  Optional[Variant[String, Sensitive[String]]] $ssl_key                = undef,
  Optional[String]                             $ssl_cert               = undef,
  Optional[String]                             $ssl_cacert             = undef,
  Optional[Stdlib::Absolutepath]               $ssl_capath             = undef,
  Optional[String]                             $ssl_cipher             = undef,
  Optional[String]                             $table_prefix           = undef,
  Optional[String]                             $instance_name          = undef,
  Optional[String]                             $instance_description   = undef,
  Optional[Boolean]                            $enable_ha              = undef,
  Optional[Icinga2::Interval]                  $failover_timeout       = undef,
  Optional[Icinga2::IdoCleanup]                $cleanup                = undef,
  Optional[Array]                              $categories             = undef,
  Variant[Boolean, Enum['mariadb', 'mysql']]   $import_schema          = false,
) {
  if ! defined(Class['icinga2']) {
    fail('You must include the icinga2 base class before using any icinga2 feature class!')
  }

  $owner                  = $icinga2::globals::user
  $group                  = $icinga2::globals::group
  $conf_dir               = $icinga2::globals::conf_dir
  $ssl_dir                = $icinga2::globals::cert_dir
  $ido_mysql_package_name = $icinga2::globals::ido_mysql_package_name
  $ido_mysql_schema       = $icinga2::globals::ido_mysql_schema
  $manage_package         = $icinga2::manage_package
  $manage_packages        = $icinga2::manage_packages

  $type                   = if $import_schema =~ Boolean {
    'mariadb'
  } else {
    $import_schema
  }

  $_notify                = $ensure ? {
    'present' => Class['icinga2::service'],
    default   => undef,
  }

  File {
    owner   => $owner,
    group   => $group,
  }

  if $enable_ssl {
    $cert = icinga2::cert(
      'IdoMysqlConnection_ido-mysql',
      $ssl_key_path,
      $ssl_cert_path,
      $ssl_cacert_path,
      $ssl_key,
      $ssl_cert,
      $ssl_cacert,
    )

    $attrs_ssl = {
      enable_ssl => true,
      ssl_ca     => $cert['cacert_file'],
      ssl_cert   => $cert['cert_file'],
      ssl_key    => Sensitive($cert['key_file']),
      ssl_capath => $ssl_capath,
      ssl_cipher => $ssl_cipher,
    }

    icinga2::tls::client { 'IdoMysqlConnection_ido-mysql':
      args   => $cert,
      notify => $_notify,
    }
  } else {
    $attrs_ssl = {
      enable_ssl => undef,
      ssl_ca     => undef,
      ssl_cert   => undef,
      ssl_key    => undef,
      ssl_capath => undef,
      ssl_cipher => undef,
    }
    $cert      = {}
  }

  $attrs = {
    host                  => $host,
    port                  => $port,
    socket_path           => $socket_path,
    user                  => $user,
    password              => Sensitive($password),
    database              => $database,
    table_prefix          => $table_prefix,
    instance_name         => $instance_name,
    instance_description  => $instance_description,
    enable_ha             => $enable_ha,
    failover_timeout      => $failover_timeout,
    cleanup               => $cleanup,
    categories            => $categories,
  }

  # install additional package
  if $ido_mysql_package_name and ($manage_package or $manage_packages) {
    if $facts['os']['family'] == 'debian' {
      ensure_resources('file', { '/etc/dbconfig-common' => { ensure => directory, owner => 'root', group => 'root' } })
      file { "/etc/dbconfig-common/${ido_mysql_package_name}.conf":
        ensure  => file,
        content => "dbc_install='false'\ndbc_upgrade='false'\ndbc_remove='false'\n",
        owner   => 'root',
        group   => 'root',
        mode    => '0600',
        before  => Package[$ido_mysql_package_name],
      }
    } # Debian

    package { $ido_mysql_package_name:
      ensure => installed,
      before => Icinga2::Feature['ido-mysql'],
    }
  }

  # import db schema
  if $import_schema {
    if $ido_mysql_package_name and ($manage_package or $manage_packages) {
      Package[$ido_mysql_package_name] -> Exec['idomysql-import-schema']
    }

    $db_cli_options = icinga2::db::connect({
        type     => $type,
        host     => $host,
        port     => $port,
        database => $database,
        username => $user,
        password => $password,
    }, $cert, $enable_ssl)

    exec { 'idomysql-import-schema':
      user    => 'root',
      path    => $facts['path'],
      command => "mysql ${db_cli_options} < \"${ido_mysql_schema}\"",
      unless  => "mysql ${db_cli_options} -Ns -e 'select version from icinga_dbversion'",
    }
  }

  # create object
  icinga2::object { 'icinga2::object::IdoMysqlConnection::ido-mysql':
    object_name => 'ido-mysql',
    object_type => 'IdoMysqlConnection',
    attrs       => delete_undef_values(merge($attrs, $attrs_ssl)),
    attrs_list  => concat(keys($attrs), keys($attrs_ssl)),
    target      => "${conf_dir}/features-available/ido-mysql.conf",
    order       => 10,
    notify      => $_notify,
  }

  # import library
  concat::fragment { 'icinga2::feature::ido-mysql':
    target  => "${conf_dir}/features-available/ido-mysql.conf",
    content => "library \"db_ido_mysql\"\n\n",
    order   => '05',
  }

  icinga2::feature { 'ido-mysql':
    ensure  => $ensure,
  }
}
