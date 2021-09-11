i=1
for d in */ ; do
    echo \'${d}final_enc\' " using 2:xtic(1)  linecolor 1 notitle col ,\\
       '' using 3:xtic(1) linecolor 2 notitle col ,\\
       '' using 4:xtic(1) linecolor 3 notitle col ,\\
       '' using 5:xtic(1) linecolor 4 notitle col ,\\
       '' using 6:xtic(1) linecolor 5 notitle col ,\\
       '' using 7:xtic(1) linecolor 5 notitle col ,\\
       newhistogram at $i,\\"
       i=$(($i + 1))
done
