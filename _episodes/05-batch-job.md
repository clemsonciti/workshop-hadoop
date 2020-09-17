---
title: "Running Hadoop as a Batch Job"
teaching: 0
exercises: 0
questions:
- "Why do we need another distributed file systems?"
objectives:
- "Motivation for HDFS"
- "Design assumptions and goals"
- "Architectural overview"
keypoints:
- "HDFS provided a new perspective on data locality, enabling large-scale data processing tasks that 
previously suffered in traditional remote large-scale storage models."
---

 Integrating Hadoop job into Palmetto workflow
With hdp module, access to Cypress Hadoop cluster can now be invoked within a Palmetto PBS script, allowing the integration of large-data processing components into a standard HPC workflow

%%writefile movieAnalyzer.pbs
#!/bin/bash

#PBS -N movieData
#PBS -l select=1:ncpus=8:mem=8gb
#PBS -l walltime=00:15:00
#PBS -j oe

# load hdp module and initilalize Keberos tokens
module load hdp/0.1
cypress-kinit
klist

# cd into directory containing the PBS script
cd $PBS_O_WORKDIR

# attempt to remove output directory
hdfs dfs -rm -r intro-to-hadoop/output-movielens-03

# submit Hadoop job to Cypress
yarn jar /usr/hdp/current/hadoop-mapreduce-client/hadoop-streaming.jar \
    -input /repository/movielens/ratings.csv \
    -output intro-to-hadoop/output-movielens-03 \
    -file ./codes/avgRatingMapper02.py \
    -mapper avgRatingMapper02.py \
    -file ./codes/avgRatingReducer02.py \
    -reducer avgRatingReducer02.py \
    -file ./movielens/movies.csv

# export output data back to Palmetto for further analysis
hdfs dfs -get intro-to-hadoop/output-movielens-03/part-00000 .
Open a terminal, ssh to login001 (DUO required), and submit this script

ssh login001
cd ~/intro-to-hadoop-python
qsub movieAnalyzer.pbs
View the final output when the job is finished

!qstat -anu $USER
!cat part-00000 2>/dev/null | head -n 20
Final Cleanup
Executing the cell below will clean up all HDFS output directories created as a result of previous MapReduce programs.

!hdfs dfs -ls intro-to-hadoop
!hdfs dfs -rm -r intro-to-hadoop/
!rm -Rf codes/
!rm -Rf movielens/

{% include links.md %}

