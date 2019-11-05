d=`date +%d%b_%Y`
vivado_dir="/tool/Xilinx/Vivado/2017.3/bin/vivado"

### cmd args ###
# hostname=$1
# shutdown_mode=$2
# time_based=$3
# iter=$4

read -p "Enter host name" hostname
read -p "Enter hws name" hws_name
read -p "Enter host shutdown mode" shutdown_mode
read -p "Enter time based 0.Random-timing or specify a time" time_based
read -p "Enter Iteration count " iter
read -p "Enter name of Test sequence " test_name
# read -p "Enter name of fio config path" kiki
read -p "Serial screen number"  screen_no
prev_word_count=0		# compare fn
shutdown_toggle=0	#use 1 for normal jtag load

home_dir=$(ssh user@"$hws_name" pwd)
screen_path="""$home_dir"/"$d"/"$test_name"/"
usb_screen="/dev/ttyUSB"$screen_no""

host_script_path="/test/shared/validation/panic/jones_test/scripts/"
fio_log_path=" /test/shared/validation/panic/jones_test/fiologs/"$d"/"$hostname"/"$test_name""
fiolog_filename="$test_name"
fio_config_path="/test/shared/validation/panic/jones_test/fill.fio"

screen_file="$screen_path"1.log
prev_timeout=0

count(){       # get count of "WCCEN" print
	keyword=$1
  	prev_word_count=$(ssh user@"$hostname"-hws1 "grep -c $keyword $screen_file")
	prev_timeout=$(ssh user@"$hostname"-hws1 "grep -c \"TIMEOUT\"  $screen_file")
}

comp(){        # check for either "WCCEN" print or "Rdy" print of MCPU
	keyword=$2
	max_words=$3
	chk_cnt=0
  # For "Rdy" check
  check="0"
	check_timeout="0"
  while [ "$check" != "$((prev_word_count+max_words))" ]; do

#	if [ "$chk_cnt" == 20 ]; then
#		ssh root@"$hostname" "/test/shared/apps/si-diags -p0000:02:00.0 -c \"read reg 0x44b06000 44\""
#		echo "Error on iter $i"
#		exit
#	fi	
	chk_cnt=$((chk_cnt+1))
	
	
	echo "Check"
    check=$(ssh user@"$hostname"-hws1 "grep -c $keyword $screen_file")
 #   prev_timeout=$check_timeout
	check_timeout=$(ssh user@"$hostname"-hws1 "grep -c \"TIMEOUT\" $screen_file")
#	if [ "$check_timeout" == $((prev_timeout+1)) ]; then
#		max_words=$((max_words+4))
#	echo $prev_timeout >>riju_test.txt
#	fi
		
	sleep 20
  done
  echo "Rdy after startup(load bitmap)"
}

jtag=0
#scp panic_screen.sh user@"$hostname"-hws1:/
ssh user@"$hostname"-hws1 mkdir -p "$screen_path" 
ssh user@"$hostname"-hws1 ./panic_screen.sh load "$usb_screen" "$screen_file"   # load screen
echo " screen loaded"

trap "echo clean-up; ssh user@$hostname-hws1 ./panic_screen.sh stop; exit" 1 2 9 EXIT    # runs if there's an interrupt signal or exit
########### Copy host script ###########
echo "copying panic_host to alap disabled"
#scp panic_host.sh root@"$hostname":"$host_script_path"
echo " All scp n ssh over"

#### State defines ####
state="custom"
sub_state="b"
i=1

while [ "$i" -lt "$iter" ]; do
	echo "$i" >> ./runsls09_1.txt
	if false ; then
		if [ "$shutdown_toggle" == "1" ]; then     #this will be the prev if it is mix ie if prev was panic we need to flash
		### Load bitmap ###
	## rdy count
	echo "In Jtag"
	count "Rdy"
  		echo "Programming Bitfiles"

   	    rm -rf check_load*
	    $vivado_dir -mode batch -source loadbm.tcl -nojournal -log check_load.viv -tclargs $hostname  >   log  2>&1  # program fpgas

	    fpga_count=$(egrep -c "End of startup status: HIGH" check_load.viv)
	    if [ "$fpga_count" != 3 ]; then
	    	echo "Device programming unsuccessful"
	    	exit
	    else
	    	echo "Device programming successful"
	    fi
	    ##rdy check
	    echo "Rdy check after load bm"
	    comp "$prev_word_count" "Rdy" 4
	   

conn=1
while [ $conn != "0" ]; do
echo "Ping-ing to host after load"
ping -c 1 "$hostname" > /dev/null 2>&1
   conn=$?
done

#if [ $((i)) -gt 2 ]; then
#reebot
sleep 20
echo "Rebooting"
#ssh root@"$hostname" "./reboot.sh"
##sleep
sleep 320
#fi

fi
fi

conn=1
while [ $conn != "0" ]; do
echo "Ping-ing to host after load"
ping -c 1 "$hostname" > /dev/null 2>&1
   conn=$?
done

#if [ $((i)) -gt 2 ]; then
#reebot
sleep 20
echo "Rebooting"
ssh root@"$hostname" "./reboot.sh"
##sleep
sleep 320

conn=1
while [ $conn != "0" ]; do
echo "Ping-ing to host after reboot"
ping -c 1 "$hostname" > /dev/null 2>&1
   conn=$?
done

echo "Checking for nvme partition"
  check="0"
  while [ "$check" == "0" ]; do
    check=$(ssh root@"$hostname" cat /proc/partitions | grep -ic nvme0n1)
    sleep 20
    echo "$check"
  done
######################################## Random scenarios cases
case $state in
                one)
			echo "Case one"
                        if [ "$sub_state" == "b" ]; then
				echo "In a"
				shutdown_mode="p"
				runtime=$((1+RANDOM%5))
				sleep_time=$((runtime+1))
				state="one"
                                sub_state="b" #edit-for only panic
				#sub_state="a"
			elif [ "$sub_state" == "a" ]; then
				echo "In b"
				shutdown_mode="g"
				runtime=$((1+RANDOM%5))
				state="two"
                                sub_state="b"
			fi
			;;
		two)
			 echo "Case two"
			if [ "$sub_state" == "b" ]; then
                                echo "In a"
				shutdown_mode="p"
                                runtime=$((1+RANDOM%6))
                                sleep_time=$((runtime))               
				state="two"
				sub_state="a"
                        elif [ "$sub_state" == "a" ]; then      
                                echo "In b"
                                shutdown_mode="g"
                                runtime=0
				sleep_time=1
				state="three"
                                sub_state="b"
                        fi
                        ;;
		three)
				echo "Three"
			if [ "$sub_state" == "b" ]; then
                                echo "In a"     
			          shutdown_mode="p"
                                runtime=$((1+RANDOM%5))
                                sleep_time=$((runtime+1))
				state="three"
                                sub_state="a"
                        elif [ "$sub_state" == "a" ]; then      
                                echo "in b"
				shutdown_mode="p"
                                runtime=0
                                sleep_time=1
				state="one"
                                sub_state="b"
                        fi
                        ;;
		custom)
				echo "Custom - LS09 issue"
			if [ "$sub_state" == "b" ]; then
				echo "PANIC"
				runtime=0
				sleep_time=1
				sub_state="b"
				shutdown_mode='p'
			elif [ "$sub_state" == "a" ]; then 
				echo "fill"
				runtime=1
                                sleep_time=1
                 #               sub_state="b"			
			fi			
			;;
	esac		
########### Mode toggle for mix, always 1 for panic ##########
	if [ "$shutdown_mode" == "m" ]; then
		if [ $((i%2)) -eq "0" ]; then
			shutdown_toggle=0
		else
			shutdown_toggle=1
		fi
	elif [ "$shutdown_mode" == "g" ]; then
		shutdown_toggle=0
	
	elif [ "$shutdown_mode" == "p" ]; then
		shutdown_toggle=1
		echo "Panic SHST"
	fi

	if [ $time_based == 0 ]; then
		runtime=$((10+RANDOM%5))
	else
		runtime=$((time_based))
	fi
	echo "Iter count $i, Toggle value $shutdown_toggle, Random timing $runtime"
#friver load check happens inside

#sleep 1m
ssh root@"$hostname" mkdir -p "$fio_log_path" 
#echo "Checking for driver"
# check="0"
#  while [ "$check" == "0" ]; do
#    check=$(ssh root@"$hostname" cat /proc/partitions | grep -ic nvme0n1)
#    sleep 20
#  done

#ssh root@"$hostname" $host_script_path $fio_config_path $i $fio_log_path$fiolog_filename $runtime &
#sleep_time=$((1+RANDOM%runtime))
#        echo "Runtime $runtime Sleeping for $sleep_time"
 #       sleep "$sleep_time"m


if [ "$shutdown_toggle" == "0" ]; then
	if [ "$runtime" != "0" ]; then
#ssh root@"$hostname" /test/shared/apps/jones_ftp_script.sh 
#count "Rdy"
#    echo "FTP Load driver"
        #ssh root@"$hostname" "modprobe nvme"
#        comp "$prev_word_count" "Rdy" 4
        sleep 30

 ssh root@"$hostname" shutdown -r now
	
	count "Rdy"
    echo "Reboot Load driver"
        #ssh root@"$hostname" "modprobe nvme"
        comp "$prev_word_count" "Rdy" 8
        sleep 20
ssh root@"$hostname" $host_script_path $fio_config_path $i $fio_log_path$fiolog_filename $runtime 
	else
		sleep "$sleep_time"m
	fi	
	        echo "Unload driver"
        ##sd done count
        #screen_file="$screen_path""$i".log #use them
       # echo "counting"
	#count "Done"
        #ssh root@"$hostname" rmmod nvme #use this for normal gc shst
#sleep 10
       #ssh root@"$hostname" shutdown -r now
	##sd done check
#echo "comparing word-done"
#        comp "$prev_word_count" "Done" 1
echo "sleeping"        
sleep 20
	#echo "done check over killing screen" #use them
        ssh user@"$hostname"-hws1 ./panic_screen.sh stop #use them
        screen_filepath="$screenlog_dir""$i".log
        ssh user@"$hostname"-hws1 ./panic_screen.sh load "$usb_screen" "$screen_path""$((i+1))".log   # load screen #use them
        screen_file="$screen_path""$((i+1))".log #use them
        count "Rdy"
    echo "Load driver"
        ssh root@"$hostname" "modprobe nvme"
        comp "$prev_word_count" "Rdy" 4
        sleep 20

	
else
	if [ "$runtime" != 0 ]; then
#		ssh root@"$hostname" $host_script_path $fio_config_path $i $fio_log_path$fiolog_filename $runtime &
		ssh root@"$hostname" "cd $host_script_path && ./panic_host.sh"
	fi
#sleep_time=$((1+RANDOM%(runtime+2)))
        echo "Runtime $runtime Sleeping for $sleep_time"
        sleep "$sleep_time"m

	echo "Panic shutdown"
#	ipmitool -H "$hostname"-ipmi -U ADMIN -P user1234 chassis power off
	curl --digest -u pnet:\<pnetlogn\> -X PUT -H "X-CSRF: x" --data "value=false" "http://pnet2/restapi/relay/outlets/0/state/" #0-taal in pnet
	sleep 20
echo "Slept for 20s"
	ssh user@"$hostname"-hws1 ./panic_screen.sh stop
	echo "Stopped sccript"
#	ipmitool -H "$hostname"-ipmi -U ADMIN -P user1234 power on
	curl --digest -u pnet:\<pnetlogn\> -X PUT -H "X-CSRF: x" --data "value=true" "http://pnet2/restapi/relay/outlets/0/state/" #0-taal value=true/false -  on/off state
	sleep 10
	screen_file="$screen_path""$((i+1))".log
echo "Screen loaded"
  	ssh user@"$hostname"-hws1 ./panic_screen.sh load "$usb_screen" "$screen_file"   # load screen
   	sleep 20
echo "slept and count rdy"
	count "Rdy"
	sleep 60
	echo "Counting rdy print"
	comp "$prev_word_count" "Rdy" 4
	echo "Startup ok from panic"
fi


i=$((i+1))

done
