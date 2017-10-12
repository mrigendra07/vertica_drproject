
sptr='################################################################################################';
while true;
    do
    ps -ef | grep heartbeat.sh | grep -v grep
    echo "$sptr jobs";
    find jobs/ -type f;

    echo "$sptr retries"
    cat tmp/._retres.sts

    echo "$sptr /tmp/dr.log";
    tail /tmp/dr.log;
    echo "$sptr internal log";
    cat tmp/._drstatus_file;

    echo "$sptr transfer status file";
    for tr_sts in `ls tmp/transfer_status/*.sts 2>/dev/null | sort `;
    do
        echo "${tr_sts}: `cat ${tr_sts}`"
    done

    echo "$sptr transfer engine lock files";
    for tr_lf in `ls tmp/._locks/engine/*.lf 2>/dev/null | sort`;
    do
        echo $tr_lf;
    done

    echo "$sptr transfer status"
    for sts_f in `ls /tmp/*_trns.sts 2>/dev/null| sort`; do
        echo
	tail $sts_f
        echo "************************************************************************************************"
    done

    echo "$sptr ini files"
    ls -l tmp/engine/*  2>/dev/null

sleep 7;clear;
done

