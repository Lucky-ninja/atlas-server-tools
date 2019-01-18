#!/bin/bash

userinstall=no
steamcmd_user=
showusage=no
migrateconfig=no

while [ -n "$1" ]; do
  case "$1" in
    --me)
      userinstall=yes
      steamcmd_user="--me"
    ;;
    -h|--help)
      showusage=yes
      break
    ;;
    --prefix=*)
      PREFIX="${1#--prefix=}"
    ;;
    --prefix)
      PREFIX="$2"
      shift
    ;;
    --exec-prefix=*)
      EXECPREFIX="${1#--exec-prefix=}"
    ;;
    --exec-prefix)
      EXECPREFIX="$2"
      shift
    ;;
    --data-prefix=*)
      DATAPREFIX="${1#--data-prefix=}"
    ;;
    --data-prefix)
      DATAPREFIX="$2"
      shift
    ;;
    --install-root=*)
      INSTALL_ROOT="${1#--install-root=}"
    ;;
    --install-root)
      INSTALL_ROOT="$2"
      shift
    ;;
    --bindir=*)
      BINDIR="${1#--bindir=}"
    ;;
    --bindir)
      BINDIR="$2"
      shift
    ;;
    --libexecdir=*)
      LIBEXECDIR="${1#--libexecdir=}"
    ;;
    --libexecdir)
      LIBEXECDIR="$2"
      shift
    ;;
    --datadir=*)
      DATADIR="${1#--datadir=}"
    ;;
    --datadir)
      DATADIR="$2"
      shift
    ;;
    --migrate-config)
      migrateconfig=yes
    ;;
    -*)
      echo "Invalid option '$1'"
      showusage=yes
      break;
    ;;
    *)
      if [ -n "$steamcmd_user" ]; then
        echo "Multiple users specified"
        showusage=yes
        break;
      elif getent passwd "$1" >/dev/null 2>&1; then
        steamcmd_user="$1"
      else
        echo "Invalid user '$1'"
        showusage=yes
        break;
      fi
    ;;
  esac
  shift
done

if [ "$userinstall" == "yes" -a "$UID" -eq 0 ]; then
  echo "Refusing to perform user-install as root"
  showusage=yes
fi

if [ "$showusage" == "no" -a -z "$steamcmd_user" ]; then
  echo "No user specified"
  showusage=yes
fi

if [ "$userinstall" == "yes" ]; then
  PREFIX="${PREFIX:-${HOME}}"
  EXECPREFIX="${EXECPREFIX:-${PREFIX}}"
  DATAPREFIX="${DATAPREFIX:-${PREFIX}/.local/share}"
  CONFIGFILE="${PREFIX}/.atlasmanager.cfg"
  INSTANCEDIR="${PREFIX}/.config/atlasmanager/instances"
else
  PREFIX="${PREFIX:-/usr/local}"
  EXECPREFIX="${EXECPREFIX:-${PREFIX}}"
  DATAPREFIX="${DATAPREFIX:-${PREFIX}/share}"
  CONFIGFILE="/etc/atlasmanager/atlasmanager.cfg"
  INSTANCEDIR="/etc/atlasmanager/instances"
fi

BINDIR="${BINDIR:-${EXECPREFIX}/bin}"
LIBEXECDIR="${LIBEXECDIR:-${EXECPREFIX}/libexec/atlasmanager}"
DATADIR="${DATADIR:-${DATAPREFIX}/atlasmanager}"

if [ "$showusage" == "yes" ]; then
    echo "Usage: ./install.sh {<user>|--me} [OPTIONS]"
    echo "You must specify your system steam user who own steamcmd directory to install ATLAS Tools."
    echo "Specify the special used '--me' to perform a user-install."
    echo
    echo "<user>          The user atlasmanager should be run as"
    echo
    echo "Option          Description"
    echo "--help, -h      Show this help text"
    echo "--me            Perform a user-install"
    echo "--prefix        Specify the prefix under which to install atlasmanager"
    echo "                [PREFIX=${PREFIX}]"
    echo "--exec-prefix   Specify the prefix under which to install executables"
    echo "                [EXECPREFIX=${EXECPREFIX}]"
    echo "--data-prefix   Specify the prefix under which to install suppor files"
    echo "                [DATAPREFIX=${DATAPREFIX}]"
    echo "--install-root  Specify the staging directory in which to perform the install"
    echo "                [INSTALL_ROOT=${INSTALL_ROOT}]"
    echo "--bindir        Specify the directory under which to install executables"
    echo "                [BINDIR=${BINDIR}]"
    echo "--libexecdir    Specify the directory under which to install executable support files"
    echo "                [LIBEXECDIR=${LIBEXECDIR}]"
    echo "--datadir       Specify the directory under which to install support files"
    echo "                [DATADIR=${DATADIR}]"
    exit 1
fi

if [ "$userinstall" == "yes" ]; then
    # Copy atlasmanager to ~/bin
    mkdir -p "${INSTALL_ROOT}${BINDIR}"
    cp atlasmanager "${INSTALL_ROOT}${BINDIR}/atlasmanager"
    chmod +x "${INSTALL_ROOT}${BINDIR}/atlasmanager"

    # Create a folder in ~/.local/share to store atlasmanager support files
    mkdir -p "${INSTALL_ROOT}${DATADIR}"

    # Copy the uninstall script to ~/.local/share/atlasmanager
    cp uninstall-user.sh "${INSTALL_ROOT}${DATADIR}/atlasmanager-uninstall.sh"
    chmod +x "${INSTALL_ROOT}${DATADIR}/atlasmanager-uninstall.sh"
    sed -i -e "s|^BINDIR=.*|BINDIR=\"${BINDIR}\"|" \
           -e "s|^DATADIR=.*|DATADIR=\"${DATADIR}\"|" \
           "${INSTALL_ROOT}${DATADIR}/atlasmanager-uninstall.sh"

    # Create a folder in ~/logs to let ATLAS tools write its own log files
    mkdir -p "${INSTALL_ROOT}${PREFIX}/logs/atlastools"

    # Create a folder in ~/.config/atlasamanger to hold instance configs
    mkdir -p "${INSTALL_ROOT}${INSTANCEDIR}"

    # Copy example instance config
    cp instance.cfg.example "${INSTALL_ROOT}/${INSTANCEDIR}/instance.cfg.example"
    # Change the defaults in the new instance config template
    sed -i -e "s|\"/home/steam|\"${PREFIX}|" \
           "${INSTALL_ROOT}${INSTANCEDIR}/instance.cfg.example"

    # Copy atlasmanager.cfg to ~/.atlasmanager.cfg.NEW
    cp atlasmanager.cfg "${INSTALL_ROOT}${CONFIGFILE}.example"
    # Change the defaults in the new config file
    sed -i -e "s|^steamcmd_user=\"steam\"|steamcmd_user=\"--me\"|" \
           -e "s|\"/home/steam|\"${PREFIX}|" \
           -e "s|/var/log/atlastools|${PREFIX}/logs/atlastools|" \
           -e "s|^install_bindir=.*|install_bindir=\"${BINDIR}\"|" \
           -e "s|^install_libexecdir=.*|install_libexecdir=\"${LIBEXECDIR}\"|" \
           -e "s|^install_datadir=.*|install_datadir=\"${DATADIR}\"|" \
           "${INSTALL_ROOT}${CONFIGFILE}.example"

    # Copy atlasmanager.cfg to ~/.atlasmanager.cfg if it doesn't already exist
    if [ -f "${INSTALL_ROOT}${CONFIGFILE}" ]; then
      SUFFIX=
      if [ "$migrateconfig" = "no" ]; then
        SUFFIX=".NEW"
        cp "${INSTALL_ROOT}${CONFIGFILE}" "${INSTALL_ROOT}${CONFIGFILE}${SUFFIX}"
      fi

      bash ./migrate-config.sh "${INSTALL_ROOT}${CONFIGFILE}${SUFFIX}"
      bash ./migrate-main-instance.sh "${INSTALL_ROOT}${CONFIGFILE}${SUFFIX}" "${INSTALL_ROOT}${INSTANCEDIR}/main.cfg${SUFFIX}"

      echo "A previous version of ATLAS Server Tools was detected in your system, your old configuration was not overwritten. You may need to manually update it."
      echo "A copy of the new configuration file was included in '${CONFIGFILE}.NEW'. Make sure to review any changes and update your config accordingly!"
      exit 2
    else
      cp -n "${INSTALL_ROOT}${CONFIGFILE}.example" "${INSTALL_ROOT}${CONFIGFILE}"
      cp -n "${INSTALL_ROOT}/${INSTANCEDIR}/instance.cfg.example" "${INSTALL_ROOT}/${INSTANCEDIR}/main.cfg"
    fi
else
    # Copy atlasmanager to /usr/bin and set permissions
    cp atlasmanager "${INSTALL_ROOT}${BINDIR}/atlasmanager"
    chmod +x "${INSTALL_ROOT}${BINDIR}/atlasmanager"

    # Copy the uninstall script to ~/.local/share/atlasmanager
    mkdir -p "${INSTALL_ROOT}${LIBEXECDIR}"
    cp uninstall.sh "${INSTALL_ROOT}${LIBEXECDIR}/atlasmanager-uninstall.sh"
    chmod +x "${INSTALL_ROOT}${LIBEXECDIR}/atlasmanager-uninstall.sh"
    sed -i -e "s|^BINDIR=.*|BINDIR=\"${BINDIR}\"|" \
           -e "s|^LIBEXECDIR=.*|LIBEXECDIR=\"${LIBEXECDIR}\"|" \
           -e "s|^DATADIR=.*|DATADIR=\"${DATADIR}\"|" \
           "${INSTALL_ROOT}${LIBEXECDIR}/atlasmanager-uninstall.sh"

    # Copy atlasdaemon to /etc/init.d ,set permissions and add it to boot
    if [ -f /lib/lsb/init-functions ]; then
      # on debian 8, sysvinit and systemd are present. If systemd is available we use it instead of sysvinit
      if [ -f /etc/systemd/system.conf ]; then   # used by systemd
        mkdir -p "${INSTALL_ROOT}${LIBEXECDIR}"
        cp systemd/atlasmanager.init "${INSTALL_ROOT}${LIBEXECDIR}/atlasmanager.init"
        sed -i "s|^DAEMON=\"/usr/bin/|DAEMON=\"${BINDIR}/|" "${INSTALL_ROOT}${LIBEXECDIR}/atlasmanager.init"
        chmod +x "${INSTALL_ROOT}${LIBEXECDIR}/atlasmanager.init"
        cp systemd/atlasmanager.service "${INSTALL_ROOT}/etc/systemd/system/atlasmanager.service"
        sed -i "s|=/usr/libexec/atlasmanager/|=${LIBEXECDIR}/|" "${INSTALL_ROOT}/etc/systemd/system/atlasmanager.service"
        cp systemd/atlasmanager@.service "${INSTALL_ROOT}/etc/systemd/system/atlasmanager@.service"
        sed -i "s|=/usr/bin/|=${BINDIR}/|;s|=steam$|=${steamcmd_user}|" "${INSTALL_ROOT}/etc/systemd/system/atlasmanager@.service"
        if [ -z "${INSTALL_ROOT}" ]; then
          systemctl daemon-reload
          systemctl enable atlasmanager.service
          echo "ATLAS server will now start on boot, if you want to remove this feature run the following line"
          echo "systemctl disable atlasmanager.service"
	fi
      else  # systemd not present, so use sysvinit
        cp lsb/atlasdaemon "${INSTALL_ROOT}/etc/init.d/atlasmanager"
        chmod +x "${INSTALL_ROOT}/etc/init.d/atlasmanager"
        sed -i "s|^DAEMON=\"/usr/bin/|DAEMON=\"${BINDIR}/|" "${INSTALL_ROOT}/etc/init.d/atlasmanager"
        # add to startup if the system use sysinit
        if [ -x /usr/sbin/update-rc.d -a -z "${INSTALL_ROOT}" ]; then
          update-rc.d atlasmanager defaults
          echo "ATLAS server will now start on boot, if you want to remove this feature run the following line"
          echo "update-rc.d -f atlasmanager remove"
        fi
      fi
    elif [ -f /etc/rc.d/init.d/functions ]; then
      # on RHEL 7, sysvinit and systemd are present. If systemd is available we use it instead of sysvinit
      if [ -f /etc/systemd/system.conf ]; then   # used by systemd
        mkdir -p "${INSTALL_ROOT}${LIBEXECDIR}"
        cp systemd/atlasmanager.init "${INSTALL_ROOT}${LIBEXECDIR}/atlasmanager.init"
        sed -i "s|^DAEMON=\"/usr/bin/|DAEMON=\"${BINDIR}/|" "${INSTALL_ROOT}${LIBEXECDIR}/atlasmanager.init"
        chmod +x "${INSTALL_ROOT}${LIBEXECDIR}/atlasmanager.init"
        cp systemd/atlasmanager.service "${INSTALL_ROOT}/etc/systemd/system/atlasmanager.service"
        sed -i "s|=/usr/libexec/atlasmanager/|=${LIBEXECDIR}/|" "${INSTALL_ROOT}/etc/systemd/system/atlasmanager.service"
        cp systemd/atlasmanager@.service "${INSTALL_ROOT}/etc/systemd/system/atlasmanager@.service"
        sed -i "s|=/usr/bin/|=${BINDIR}/|;s|=steam$|=${steamcmd_user}|" "${INSTALL_ROOT}/etc/systemd/system/atlasmanager@.service"
        if [ -z "${INSTALL_ROOT}" ]; then
          systemctl daemon-reload
          systemctl enable atlasmanager.service
          echo "ATLAS server will now start on boot, if you want to remove this feature run the following line"
          echo "systemctl disable atlasmanager.service"
        fi
      else # systemd not preset, so use sysvinit
        cp redhat/atlasdaemon "${INSTALL_ROOT}/etc/rc.d/init.d/atlasmanager"
        chmod +x "${INSTALL_ROOT}/etc/rc.d/init.d/atlasmanager"
        sed -i "s@^DAEMON=\"/usr/bin/@DAEMON=\"${BINDIR}/@" "${INSTALL_ROOT}/etc/rc.d/init.d/atlasmanager"
        if [ -x /sbin/chkconfig -a -z "${INSTALL_ROOT}" ]; then
          chkconfig --add atlasmanager
          echo "ATLAS server will now start on boot, if you want to remove this feature run the following line"
          echo "chkconfig atlasmanager off"
        fi
      fi
    elif [ -f /sbin/runscript ]; then
      cp openrc/atlasdaemon "${INSTALL_ROOT}/etc/init.d/atlasmanager"
      chmod +x "${INSTALL_ROOT}/etc/init.d/atlasmanager"
      sed -i "s@^DAEMON=\"/usr/bin/@DAEMON=\"${BINDIR}/@" "${INSTALL_ROOT}/etc/init.d/atlasmanager"
      if [ -x /sbin/rc-update -a -z "${INSTALL_ROOT}" ]; then
        rc-update add atlasmanager default
        echo "ATLAS server will now start on boot, if you want to remove this feature run the following line"
        echo "rc-update del atlasmanager default"
      fi
    elif [ -f /etc/systemd/system.conf ]; then   # used by systemd
      mkdir -p "${INSTALL_ROOT}${LIBEXECDIR}"
      cp systemd/atlasmanager.init "${INSTALL_ROOT}${LIBEXECDIR}/atlasmanager.init"
      sed -i "s|^DAEMON=\"/usr/bin/|DAEMON=\"${BINDIR}/|" "${INSTALL_ROOT}${LIBEXECDIR}/atlasmanager.init"
      chmod +x "${INSTALL_ROOT}${LIBEXECDIR}/atlasmanager.init"
      cp systemd/atlasmanager.service "${INSTALL_ROOT}/etc/systemd/system/atlasmanager.service"
      sed -i "s|=/usr/libexec/atlasmanager/|=${LIBEXECDIR}/|" "${INSTALL_ROOT}/etc/systemd/system/atlasmanager.service"
      cp systemd/atlasmanager@.service "${INSTALL_ROOT}/etc/systemd/system/atlasmanager@.service"
      sed -i "s|=/usr/bin/|=${BINDIR}/|;s|=steam$|=${steamcmd_user}|" "${INSTALL_ROOT}/etc/systemd/system/atlasmanager@.service"
      if [ -z "${INSTALL_ROOT}" ]; then
        systemctl daemon-reload
        systemctl enable atlasmanager.service
        echo "ATLAS server will now start on boot, if you want to remove this feature run the following line"
        echo "systemctl disable atlasmanager.service"
      fi
    fi

    # Create a folder in /var/log to let ATLAS tools write its own log files
    mkdir -p "${INSTALL_ROOT}/var/log/atlastools"
    chown "$steamcmd_user" "${INSTALL_ROOT}/var/log/atlastools"

    # Create a folder in /etc/atlasmanager to hold instance config files
    mkdir -p "${INSTALL_ROOT}${INSTANCEDIR}"
    chown "$steamcmd_user" "${INSTALL_ROOT}${INSTANCEDIR}"

    # Copy example instance config
    cp instance.cfg.example "${INSTALL_ROOT}${INSTANCEDIR}/instance.cfg.example"
    chown "$steamcmd_user" "${INSTALL_ROOT}${INSTANCEDIR}/instance.cfg.example"
    # Change the defaults in the new instance config template
    sed -i -e "s|\"/home/steam|\"/home/$steamcmd_user|" \
           "${INSTALL_ROOT}${INSTANCEDIR}/instance.cfg.example"

    # Copy atlasmanager bash_completion into /etc/bash_completion.d/
    cp bash_completion/atlasmanager "${INSTALL_ROOT}/etc/bash_completion.d/atlasmanager"

    # Copy atlasmanager.cfg inside linux configuation folder if it doesn't already exists
    mkdir -p "${INSTALL_ROOT}/etc/atlasmanager"
    chown "$steamcmd_user" "${INSTALL_ROOT}/etc/atlasmanager"
    cp atlasmanager.cfg "${INSTALL_ROOT}${CONFIGFILE}.example"
    chown "$steamcmd_user" "${INSTALL_ROOT}${CONFIGFILE}.example"
    sed -i -e "s|^steamcmd_user=\"steam\"|steamcmd_user=\"$steamcmd_user\"|" \
           -e "s|\"/home/steam|\"/home/$steamcmd_user|" \
           -e "s|^install_bindir=.*|install_bindir=\"${BINDIR}\"|" \
           -e "s|^install_libexecdir=.*|install_libexecdir=\"${LIBEXECDIR}\"|" \
           -e "s|^install_datadir=.*|install_datadir=\"${DATADIR}\"|" \
           "${INSTALL_ROOT}${CONFIGFILE}.example"

    if [ -f "${INSTALL_ROOT}${CONFIGFILE}" ]; then
      SUFFIX=
      if [ "$migrateconfig" = "no" ]; then
        SUFFIX=".NEW"
        cp "${INSTALL_ROOT}${CONFIGFILE}" "${INSTALL_ROOT}${CONFIGFILE}${SUFFIX}"
      fi

      bash ./migrate-config.sh "${INSTALL_ROOT}${CONFIGFILE}${SUFFIX}"
      bash ./migrate-main-instance.sh "${INSTALL_ROOT}${CONFIGFILE}${SUFFIX}" "${INSTALL_ROOT}${INSTANCEDIR}/main.cfg${SUFFIX}"

      echo "A previous version of ATLAS Server Tools was detected in your system, your old configuration was not overwritten. You may need to manually update it."
      echo "A copy of the new configuration file was included in /etc/atlasmanager. Make sure to review any changes and update your config accordingly!"
      exit 2
    else
      cp -n "${INSTALL_ROOT}${CONFIGFILE}.example" "${INSTALL_ROOT}${CONFIGFILE}"
      cp -n "${INSTALL_ROOT}/${INSTANCEDIR}/instance.cfg.example" "${INSTALL_ROOT}/${INSTANCEDIR}/main.cfg"
    fi
fi

exit 0
