
for f in parse_statsjson.pl run_stats.pl
do
    echo "########## DIFF: $f #############"
    colordiff $f /data/bnf/scripts/$f
done

read -p "Have you tested everything???? " -n 1 -r

echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    echo "Deploying..."
    cp parse_statsjson.pl /data/bnf/scripts
    cp run_stats.pl /data/bnf/scripts
    echo "DONE!"
fi



