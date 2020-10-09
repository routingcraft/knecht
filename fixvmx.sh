#!/bin/bash

rm -rf /mnt/knecht
mkdir /mnt/knecht
killall qemu-nbd 2>/dev/null

if [[ $# -eq 0 ]]
then
    echo "Please specify directory with image"
    exit 1
fi
if [[ ! -f $1/virtiob.qcow2 ]]
then
    echo "File $1/virtiob.qcow2 not found"
    exit 1
fi

echo "Editing $1/virtiob.qcow2"

modprobe ufs
modprobe nbd max_part=63

qemu-nbd -c /dev/nbd0 $1/virtiob.qcow2
sleep 1
killall qemu-nbd
qemu-nbd -c /dev/nbd0 $1/virtiob.qcow2
sleep 1
mount -t ufs -o rw,ufstype=44bsd /dev/nbd0p6 /mnt/knecht
mount -t ufs -o rw,remount,ufstype=44bsd /dev/nbd0p6 /mnt/knecht
sleep 1

rm /mnt/knecht/juniper.conf*

cat <<EOT >> /mnt/knecht/juniper.conf
system {
    login {
        user admin {
            uid 2000;
            class super-user;
            authentication {
                encrypted-password "\$6\$r87PDyOQ\$3eD4k3hGb4vdL6ttqzjSwj39Mz7rCDedq73Ij0gRe4uOffsacTsTMta16ZlpZtO2OoGjmoAtyPynqDeM9T.Gs1"; ## SECRET-DATA
EOT
# if public key exists on local host, add it to VM config
if [[ -f ~/.ssh/id_rsa.pub ]]
then
     echo "ssh-rsa \"`cat ~/.ssh/id_rsa.pub`\"; ## SECRET-DATA" >> /mnt/knecht/juniper.conf
fi
cat <<EOT >> /mnt/knecht/juniper.conf
            }
        }
    }
    root-authentication {
        encrypted-password "\$6$/KPCLpca\$wESeuKafILeP15NOq2xGYD9Xm9p/S.un6nnsDmiJJOgLRxY3rKoH37t8qvjKcog2cmzjjZrf1JAxZIUrs4I0s0"; ## SECRET-DATA
    }
    services {
        ssh {
            root-login allow;
        }
        xnm-clear-text;
        netconf {
            ssh;
        }
    }
    syslog {
        user * {
            any emergency;
            match "!(.*Scheduler Oinker*.|.*Frame 0*.|.*ms without yielding*.)";
        }
        file messages {
            any any;
            match "!(.*Scheduler Oinker*.|.*Frame 0*.|.*ms without yielding*.)";
            authorization info;
            
        }
        file interactive-commands {
            interactive-commands any;
        }
    }
    processes {
        dhcp-service {
            traceoptions {
                file dhcp_logfile size 10m;
                level all;
                flag packet;
            }
        }
    }
}
chassis {
    fpc 0 {
        lite-mode;
        number-of-ports 8;
    }
}
interfaces {
    fxp0 {
        unit 0 {
            family inet {
                dhcp;
            }
        }
    }
}
protocols {
    lldp {
        interface all;
    }
}
EOT

gzip /mnt/knecht/juniper.conf

umount /mnt/knecht
killall qemu-nbd
