for i in *.jpg
do 
     ls -1 ${i%.*}.sift 2> /dev/null
	if [ $? -eq 1 ]
 		then
		echo $i >> newlist
	fi
done
