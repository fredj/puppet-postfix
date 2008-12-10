#########################################################################
#
# This class provides a basic setup of postfix with local and remote
# delivery and an SMTP server listening on the loopback interface.
#

class postfix-ng {

  # Default value for various options
  case $postfix_ng_smtp_listen {
    "": { $postfix_ng_smtp_listen = "127.0.0.1" }
  }
  case $root_mail_recipient {
    "":   { $root_mail_recipient = "nobody" }
  }


  package { ["postfix", "mailx"]:
    ensure => installed
  }

  service { "postfix":
    ensure  => running,
    require => Package["postfix"],
  }

  file { "/etc/mailname":
    ensure  => present,
    content => "${fqdn}\n",
    seltype => "postfix_etc_t",
  }

  # Aliases

  file { "/etc/aliases":
    ensure => present,
    content => "# file managed by puppet\n",
    replace => false,
    seltype => "postfix_etc_t",
    notify => Exec["newaliases"],
  }

  exec { "newaliases":
    command     => "/usr/bin/newaliases",
    refreshonly => true,
    require     => Package["postfix"],
    subscribe   => File["/etc/aliases"],
  }

  # Config files

  file { "/etc/postfix/master.cf":
    ensure  => present,
    content => $lsbdistcodename ? {
      Tikanga => template("postfix-ng/master.cf.redhat5.erb"),
      etch => template("postfix-ng/master.cf.debian-etch.erb"),
      default => "No puppet template defined for $lsbdistcodename\n",
    },
    notify  => Service["postfix"],
    require => Package["postfix"],
  }

  file { "/etc/postfix/main.cf":
    ensure  => present,
    source  => "puppet:///postfix-ng/main.cf",
    replace => false,
    notify  => Service["postfix"],
    require => Package["postfix"],
  }

  # Default configuration parameters

  postfix-ng::config {
    "myorigin":   value => "${fqdn}";
    "alias_maps": value => "hash:/etc/aliases";
    "inet_interfaces": value => "all";
  }

  case $operatingsystem {
    RedHat: {
      postfix-ng::config {
        "sendmail_path": value => "/usr/sbin/sendmail.postfix";
        "newaliases_path": value => "/usr/bin/newaliases.postfix";
        "mailq_path": value => "/usr/bin/mailq.postfix";
      }
    }
  }

  mailalias {"root":
    recipient => $root_mail_recipient,
    notify    => Exec["newaliases"],
  }
}
