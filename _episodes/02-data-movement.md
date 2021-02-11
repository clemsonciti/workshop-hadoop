---
title: "Data movement on Hadoop"
teaching: 0
exercises: 0
questions:
- "How do I move data in and out of the Hadoop cluster"
objectives:
- "Know to update .bashrc for the relevant modules."
- "Know how to request nodes and launch the Hadoop cluster."
- "Know the distribution of HDFS components on the nodes."
- "Know how to copy data into and get data out of HDFS."
keypoints:
- "HDFS provides an abstract of a file system. Terminal commands are needed for file movements."
---

> ## Updating .bashrc
> 
> - Run the following command
>
> ~~~
> $ echo "module load openjdk/1.8.0_222-b10-gcc/8.3.1 hadoop/3.2.1-gcc/8.3.1" >> ~/.bashrc
> ~~~
> {: language-bash}
{: .slide}

> ## Requesting resources
>
> ~~~
> $ qsub -I -l select=3:ncpus=8:mem=14gb:interconnect=1g,walltime=03:30:00
> ~~~
> {: .language-bash}
{: .slide}

> ## Copying the myhadoop template from /zfs/citi
>
> - After request is granted
>
> ~~~
> $ cp -R /zfs/citi/myhadoop/ ~/
> $ cd ~/myhadoop
> ~~~
> {: .language-bash}
{: .slide}

> ## Examining the myhadoop template
>
> ~~~
> $ ls -l
> $ ls -l bin/
> ~~~
> {: .language-bash}
>
> - `init_hadoop.sh`: format and launch a new Hadoop cluster on the allocated resources. 
> - `test_hadoop.sh`: quickly test the newly launched cluster.
> - `stop_hadoop.sh`: stop the Hadoop cluster and clean up all data storage.
> - `bin/myhadoop.sh`: launch all components of Hadoop. 
> - `bin/myhadoop_shutdown.sh`: stop all components of Hadoop. 
{: .slide}

> ## Launching myhadoop
>
> ~~~
> $ ./init_hadoop.sh
> ~~~
> {: .language-bash}
>
> The final command in `init_hadoop.sh` will show the results of a system check. A successful
> launch will show the number of live data nodes being one less than the total number of nodes
> requested from Palmetto. 
>
{: .slide}

> ## Testing myhadoop
>
> ~~~
> $ ./test_hadoop.sh
> ~~~
> {: .language-bash}
>
> A succesful test will show the completed run of the test WordCount program
>
{: .slide}


> ## Hadoop main commands
> 
> Users can interact with Hadoop via command and subcommand. The primary command to interact
> with Hadoop is `hdfs`. A subcommand related to file system operations is `dfs`. Entering these
> commands without parameters will give you the usage. 
> 
> ~~~
> $ hdfs
> $ hdfs dfs
> ~~~
> {: .language-bash}
{: .slide}

> ## Specifying configuration location
> 
> We need to specify the location of the configuration files for our hadoop cluster. This
> can be done by setting the `HDAOOP_CONF_DIR` environment variable. 
>
> ~~~
> $ export HADOOP_CONF_DIR="/home/$USER/hadoop_palmetto/config/"
> $ hdfs dfs -mkdir /user/
> $ hdfs dfs -mkdir /user/$USER
> $ hdfs dfs -ls /user/
> $ hdfs dfs -ls /user/$USER
> ~~~
> {: language-bash}
>
{: .slide}



> ## Challenge: creating a directory
> 
> Create a directory named `intro-to-hadoop` inside your user directory on HDFS. Confirm
> that the directory was successfully created. 
>
> > ## Solution: 
> > 
> > ~~~
> > $ hdfs dfs -mkdir /user/$USER/intro-to-hadoop
> > $ hdfs dfs -ls /user/$USER
> > ~~~
> > {: .language-bash}
> {: .solution}
{: .challenge}

> ## Home directory on HDFS
> 
> In HDFS, the home directory is defaulted to be `/user/$USER` with `$USER` is
> your username. 
>
> ~~~
> $ hdfs dfs -ls /user/$USER
> $ hdfs dfs -ls 
> $ hdfs dfs -ls .
> ~~~
> {: language-bash}
>
{: .slide}

> ## Uploading and downloading files
> 
> To upload data into HDFS, we use the subsubcommand `put`. To download data from HDFS, 
> we use the subsubcommand `get`. 
>
> ~~~
> $ hdfs dfs -put /zfs/citi/complete-shakespeare.txt intro-to-hadoop/
> $ hdfs dfs -ls intro-to-hadoop
> $ hdfs dfs -head intro-to-hadoop/complete-shakespeare.txt
> $ hdfs dfs -get intro-to-hadoop/complete-shakespeare.txt ~/shakespeare-complete.txt
> $ head ~/shakespeare-complete.txt
> $ diff /zfs/citi/complete-shakespeare.txt ~/shakespeare-complete.txt
> ~~~
> {: .language-bash}
>
{: .slide}


> ## Uploading and downloading directories
>
> The `put` and `get` subsubcommands can also be used to move directories as well as 
> individual files. 
>
> ~~~
> $ hdfs dfs -put /zfs/citi/movielens intro-to-hadoop/
> $ hdfs dfs -ls intro-to-hadoop
> $ hdfs dfs -ls intro-to-hadoop/movielens
> ~~~
> {: .language-bash}
>
{: .slide}

> ## Checking health status of files and directories in HDFS:
> 
> ~~~
> $ hdfs fsck intro-to-hadoop/ -files -blocks -locations
> ~~~
> {: .language-bash}
{: .slide}

{% include links.md %}
