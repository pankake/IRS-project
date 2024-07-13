i=1
while test $i -le 100
do
  argos3 -c test-subs_experiment_v1.argos | tail -n 2 | grep f_distance | cut -f2 -d' ' >> results_subs_v1.txt
  i=`expr $i + 1`
done