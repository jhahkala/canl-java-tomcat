grep eth1 /etc/udev/rules.d/70-persistent-net.rules 
RES=$?
if [ $RES -eq 0 ]; then
    echo changing the eth1 to eth0
    cp /etc/udev/rules.d/70-persistent-net.rules rules.bak
    cat /etc/udev/rules.d/70-persistent-net.rules |grep -v eth0|sed "s/eth1/eth0/" >rules
    cp rules /etc/udev/rules.d/70-persistent-net.rules 
fi
echo Changing the network config hw address
cp /etc/sysconfig/network-scripts/ifcfg-eth0 ifcnf.bak
cat /etc/sysconfig/network-scripts/ifcfg-eth0 |grep -v HWADDR >ifcnf
echo HWADDR=\"`grep eth /etc/udev/rules.d/70-persistent-net.rules |awk '{print $4}'|awk -F\" '{print $2}'`\" >>ifcnf
cp ifcnf /etc/sysconfig/network-scripts/ifcfg-eth0
reboot now
