#!/bin/bash

# Path to the script
SCRIPT=$(readlink -f $0)
SCRIPTPATH=`dirname $SCRIPT`
echo -n "path to script: $SCRIPTPATH"

pdb=$1
outpath=$2

if [ ! -d $outpath ]
then
    mkdir $outpath
fi

id=$(basename $pdb)
outfile=$outpath/${id%.pdb}_all_csym.dat
c2_rmsd_cutoff=4
c2_clash_cutoff=200

declare -a listrmsd=()

echo $id
echo $outpath

echo "symmetry av.rmsd clashscore" > $outfile

for sym in 2 3 4 5 6 7 8 9 10 11 12
do
    rmsd="NA"
    clashscore="NA"
    rmsd=`$ANANAS $pdb c$sym -C 100 | grep "Average RMSD" | awk '{ print $4 }' `

    do_score=`awk -v a=$rmsd -v rcut=$c2_rmsd_cutoff 'BEGIN { print (a<=rcut) ? "YES" : "NO" }'`

    if [ "$do_score" == "YES" ]
    then
        $ANANAS $pdb c$sym --symmetrize $outpath/${id%.pdb}_c${sym}.pdb
        clashscore=`$PHENIX_CLASHSCORE model=$outpath/${id%.pdb}_c${sym}.pdb | grep -i "clashscore" | head -n1 | sed -E 's/.*=[[:space:]]*//'`
        echo -e "\n*************************\nrmsd : $rmsd\n*************************\n"
        echo -e "\n*************************\nclashscore : $clashscore\n*************************\n"
        rm -f $outpath/${id%.pdb}_c${sym}.pdb
    fi

    echo c$sym $rmsd $clashscore >> $outfile

    if [ $sym == 2 ]
    then
        is_c2_ok=`awk -v a=$rmsd -v cs=$clashscore -v rcut=$c2_rmsd_cutoff -v ccut=$c2_clash_cutoff 'BEGIN { print ((a<=rcut && cs!="NA" && cs<=ccut) ? "YES" : "NO") }'`
        if [ "$is_c2_ok" == "YES" ]
        then
            break
        fi
    fi
done