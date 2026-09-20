cd ./snapshot_runs

while read dir; do
  cd $dir
  echo "queueing $dir"
  sbatch ./tree-changed-after-parallel.sh
  cd ..
done < dirs.txt

cd ../active_runs

while read dir; do
  cd $dir
  echo "queueing $dir"
  sbatch ./tree-changed-after-parallel.sh
  cd ..
done < dirs.txt