args=""
read -p "code to execute: " fname
echo $fname
read -p "give secure function name: " sec_func
echo "give function arguments: "
while   read line && ${line:+":"} break
do
    if [[ $args == "" ]]
    then
        args="$line"
    else
        args="$args,$line"
    fi

done
cp $fname $fname"_secure"
