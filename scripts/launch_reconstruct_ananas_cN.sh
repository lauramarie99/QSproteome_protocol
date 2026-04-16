#!/bin/bash
export LC_ALL=C
export LANG=C
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
best_rmsd=100
best_sym=0
best_clash="NA"
c12_rmsd="NA"

listrmsd=()

echo $id
echo $outpath

echo "symmetry av.rmsd clashscore" > $outfile

for sym in 2 3 4 5 6 7 8 9 10 11 12
do
    rmsd="NA"
    clashscore="NA"

    rmsd=`$ANANAS $pdb c$sym -C 100 | grep "Average RMSD" | awk '{ print $4 }' `

    if [[ "$rmsd" != "NA" && -n "$rmsd" ]]
    then
        rmsd_short=$(printf "%.3f" "$rmsd")
        if [[ " ${listrmsd[*]} " =~ " ${rmsd_short} " ]]
        then
            echo c$sym $rmsd $clashscore >> $outfile
            continue
        else
            listrmsd+=("$rmsd_short")
        fi
    fi

    # symmetry-specific RMSD cutoff
    if [ "$sym" -eq 2 ] || [ "$sym" -eq 3 ]; then
        rmsd_cutoff=4
    elif [ "$sym" -eq 4 ]; then
        rmsd_cutoff=3.5
    elif [ "$sym" -eq 5 ]; then
        rmsd_cutoff=3
    else
        rmsd_cutoff=2.5
    fi

    do_score=$(awk -v a="$rmsd" -v rcut="$rmsd_cutoff" 'BEGIN { if (a != "" && a != "NA" && a < rcut) print "YES"; else print "NO" }')

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
        is_c2_ok=`awk -v a=$rmsd -v rcut=$c2_rmsd_cutoff 'BEGIN { print (a<rcut) ? "YES" : "NO" }'`
        if [ "$is_c2_ok" == "YES" ]
        then
            best_sym=$sym
            best_rmsd=$rmsd
            best_clash=0
            break
        fi
    else
        is_better=$(awk -v a="$rmsd" -v b="$best_rmsd" 'BEGIN { if (a != "" && a != "NA" && a < b) print "YES"; else print "NO" }')
        if [ "$is_better" = "YES" ]
        then
            best_sym=$sym
            best_rmsd=$rmsd
            best_clash=$clashscore
            if [ "$sym" -eq 12 ]; then
                c12_rmsd=$rmsd
            fi
        fi
    fi 
done

# only continue to higher symmetries if the best symmetry from C3-C12 is C12
if [ "$best_sym" -eq 12 ]
then
    for sym in 13 14 15 16 17 18 19 20 21 22 23 24
    do
        rmsd="NA"
        clashscore="NA"

        rmsd=$($ANANAS "$pdb" c$sym -C 100 | grep "Average RMSD" | awk '{ print $4 }')

        if [[ "$rmsd" != "NA" && -n "$rmsd" ]]
        then
            rmsd_short=$(printf "%.3f" "$rmsd")
            if [[ " ${listrmsd[*]} " =~ " ${rmsd_short} " ]]
            then
                echo c$sym $rmsd $clashscore >> $outfile
                continue
            else
                listrmsd+=("$rmsd_short")
            fi
        fi

        if [ "$sym" -eq 13 ] || [ "$sym" -eq 14 ]; then
            rmsd_cutoff=2
        else
            rmsd_cutoff=1.5
        fi

        do_score=$(awk -v a="$rmsd" -v rcut="$rmsd_cutoff" 'BEGIN { if (a != "" && a != "NA" && a < rcut) print "YES"; else print "NO" }')

        if [ "$do_score" = "YES" ]
        then
            $ANANAS "$pdb" c$sym --symmetrize "$outpath/${id%.pdb}_c${sym}.pdb"
            clashscore=$($PHENIX_CLASHSCORE model="$outpath/${id%.pdb}_c${sym}.pdb" | grep -i "clashscore" | head -n1 | sed -E 's/.*=[[:space:]]*//')
            rm -f "$outpath/${id%.pdb}_c${sym}.pdb"
        fi

        echo c$sym $rmsd $clashscore >> "$outfile"

    done
fi