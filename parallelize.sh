#!/bin/bash

# -----------------------------
parallelize() {
    case $# in
    1)
        task_or_file="$1"
        ;;
    2)
        task_or_file="$1"
        process="$2"
        ;;
    *)
        >&2 echo "error: unexpected parameters"
        exit 1
        ;;
    esac
    : ${process:=4}

    if [[ -f "$task_or_file" ]]; then
        proc=cat
    else
        proc=echo
    fi
    tasks_num=$($proc $task_or_file | wc -l)

    tempfifo=$$.fifo        # $$表示当前执行文件的PID

    log_path="$PWD/mplogs"
    out_path="$PWD/mpout"
    rm -rf $log_path $out_path
    mkdir -p $log_path $out_path

    # -----------------------------

    trap "exec 1024>&-;exec 1024<&-;exit 0" 2
    mkfifo $tempfifo
    exec 1024<>$tempfifo
    rm -rf $tempfifo

    for ((i=1; i<=$process; i++))
    do
        echo >&1024
    done
    # --------------------------------

    echo "==> task num: $tasks_num"
    echo "==> concurrence num: $process"
    echo "---------------------------"

    i=1
    $proc $task_or_file | while read task 
    do
        read -u1024
        echo "task running $i/$tasks_num"
        {
            eval "$task" > "$log_path/$i.log"  2>&1
            if [ $? -ne 0 ]
            then
                mv "$log_path/$i.log" "$log_path/$i.err"
            else
                mv "$log_path/$i.log" "$log_path/$i.ok"
            fi
            echo >&1024
        } &
        i=$(($i+1))
    done

    wait

    # ---------------------------------------------
    ok=$(ls $log_path | grep ok | wc -l)
    err=$(ls $log_path | grep err  | wc -l)
    # get err task id and log
    # err_id=$(ls $log_path | grep err | cut -d'.' -f 1)
    # err_log=$(ls $log_path | grep err)

    cat $log_path/* > $out_path/parallelize.out
    cat $log_path/*.err > $out_path/parallelize.err
    rm -rf $log_path

    echo "---------------------------"
    echo "==> parallelize done..."
    echo "==> sucess: $ok, fail: $err"
    echo "==> your can find sucess log in parallelize.out, and error log in parallelize.err"
}
