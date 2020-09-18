---
title: "Programming and debugging Hadoop MapReduce"
teaching: 0
exercises: 0
questions:
- "How do we write programs to leverage HDFS's data placement?"
objectives:
- "Understand the MapReduce programming paradigm."
- "Be able to implement simple Python-based map and reduce tasks."
- "Be able to run the Python-based map and reduce tasks on HDFS data."
keypoints:
- "To leverage HDFS, we need to use a programming paradigm called MapReduce. With Hadoop's
streaming support, we can write map and reduce tasks in any language and apply these tasks
on data stored in HDFS."
---

> ## MapReduce Programming Paradigm
> - **Map**: A function/procedure that is applied to every individual elements of a collection/list/array.
> 
> ~~~
> int square(x) { return x*x;}
> map square [1,2,3,4] -> [1,4,9,16]
> ~~~
>
> - **Reduce**: A function/procedure that performs an operation on a list. This operation will 
> *fold/reduce* this list into a single value (or a smaller subset).
>
> ~~~
> reduce ([1,2,3,4]) using sum -> 10
> reduce ([1,2,3,4]) using multiply -> 24
> ~~~
{: .slide}

> ## MapReduce over Hadoop HDFS
> 
> MapReduce is an old concept in functional programming. It is naturally applicable in HDFS:  
> - Map tasks are performed on top of individual data blocks (mainly to filter and decrease 
> raw data contents while increase data value.
> - Reduce tasks are performed on intermediate results from map tasks (should now be 
> significantly decreased in size) to calculate the final results.
{: .slide}

> ## The Hello World of Hadoop: Word Count
> 
> Count the number of uniques in a document(s).  
>
> ~~~
> $ hdfs dfs -cat intro-to-hadoop/complete-shakespeare.txt 2>/dev/null | head -n 20
> $ cat -n codes/wcMapper.py
> $ hdfs dfs -cat intro-to-hadoop/complete-shakespeare.txt 2>/dev/null | head -n 20 | python ./codes/wcMapper.py
> $ hdfs dfs -cat intro-to-hadoop/complete-shakespeare.txt 2>/dev/null | head -n 20 | python ./codes/wcMapper.py | sort
> $ cat -n codes/wcReducer.py
> $ hdfs dfs -cat intro-to-hadoop/complete-shakespeare.txt 2>/dev/null | head -n 20 | python ./codes/wcMapper.py | sort | python ./codes/wcReducer.py
> ~~~
> {: .language-bash}
{: .slide}

> ## Run WordCount on the Hadoop cluster
>
> ~~~
> $ hdfs dfs -rm -R intro-to-hadoop/output-wordcount 
> $ mapred streaming -input intro-to-hadoop/complete-shakespeare.txt -output intro-to-hadoop/output-wordcount -file ./codes/wcMapper.py -mapper wcMapper.py -file ./codes/wcReducer.py -reducer wcReducer.py
> $ hdfs dfs -ls intro-to-hadoop/output-wordcount
> $ hdfs dfs -cat intro-to-hadoop/output-wordcount/part-00000 2>/dev/null | head -n 100
> ~~~
> {: .language-bash}
{: .slide}

> ## Data: Movie Ratings and Recommendation
> 
> **MovieLens**: This dataset contains 24404096 ratings and 668953 tag applications 
> across 40110 movies. These data were created by 247753 users between January 09, 1995 
> and January 29, 2016. This dataset was generated on October 17, 2016.
>
> - Find average ratings of all movies. 
> - Find average ratings of all genres. 
>
> ~~~
> $ hdfs dfs -ls -h intro-to-hadoop/movielens
> $ hdfs dfs -cat intro-to-hadoop/movielens/README.txt
> $ hdfs dfs -cat intro-to-hadoop/movielens/links.csv 2>/dev/null | head -n 10
> $ hdfs dfs -cat intro-to-hadoop/movielens/movies.csv 2>/dev/null | head -n 10
> $ hdfs dfs -cat intro-to-hadoop/movielens/ratings.csv 2>/dev/null | head -n 10
> ~~~
> {: .language-bash}
> 
> To write a MapReduce program, you have to be able to identify the necessary (Key,Value) 
> that can contribute to the final realization of the required results. This is the reducing 
> phase. From this (Key,Value) pair format, you will be able to develop the mapping phase.
{: .slide}

> ## Mapper 01: extract rating information
> 
> ~~~
> $ cat -n codes/avgRatingMapper01.py
> $ hdfs dfs -cat intro-to-hadoop/movielens/ratings.csv 2>/dev/null | head -n 10 | python ./codes/avgRatingMapper01.py
> ~~~
> {: .language-bash}
> 
> Do we really need the headers?
{: .slide}

> ## Mapper 02: extract rating information without header
> 
> ~~~
> $ cat -n codes/avgRatingMapper02.py
> $ hdfs dfs -cat intro-to-hadoop/movielens/ratings.csv 2>/dev/null | head -n 10 | python ./codes/avgRatingMapper02.py
> ~~~
> {: .language-bash}
> 
> The outcome is correct. Is it useful?
{: .slide}

> ## Mapper 03: get additional files
> 
> ~~~
> $ mkdir movielens
> $ hdfs dfs -get intro-to-hadoop/movielens/movies.csv movielens/
> $ cat -n codes/avgRatingMapper03.py
> $ hdfs dfs -cat intro-to-hadoop/movielens/ratings.csv 2>/dev/null | head -n 10 | python ./codes/avgRatingMapper03.py
> ~~~
> {: .language-bash}
> 
> The outcome is correct. Is it useful?
{: .slide}

> ## Reducer01: simple reducer
>
> ~~~
> $ cat -n codes/avgRatingReducer01.py
> $ hdfs dfs -cat intro-to-hadoop/movielens/ratings.csv 2>/dev/null | head -n 10 | python ./codes/avgRatingMapper03.py | sort | python ./codes/avgRatingReducer01.py
> ~~~
> {: .language-bash}
>
> How do we test for correctness?
{: .slide}

> ## Non-HDFS correctness test
>
> ~~~
> $ hdfs dfs -cat intro-to-hadoop/movielens/ratings.csv 2>/dev/null | head -n 2000 | python ./codes/avgRatingMapper03.py | grep Matrix
> $ hdfs dfs -cat intro-to-hadoop/movielens/ratings.csv 2>/dev/null | head -n 2000 | python ./codes/avgRatingMapper03.py | grep Matrix | sort | python ./codes/avgRatingReducer01.py
> ~~~
> {: .language-bash}
>
> Run a manual calculation comparison
{: .slide}

> ## Full execution on HDFS
> 
> ~~~
> $ mapred streaming -input intro-to-hadoop/movielens/ratings.csv -output intro-to-hadoop/output-movielens-01 -file ./codes/avgRatingMapper03.py -mapper avgRatingMapper03.py -file ./codes/avgRatingReducer01.py -reducer avgRatingReducer01.py
> ~~~
> {: .language-bash}
>
> Yay, first error!!!
{: .slide}

> ## What exactly is the error?
>
> Go back to the first few lines of the previously and look for the INFO line **Submitted 
> application application_xxxx_xxxx**. Running the logs command of yarn with the provided 
> application ID is a straightforward way to access all available log information for that 
> application. The syntax to view yarn log is:
> 
> ~~~
> $ yarn logs -applicationId APPLICATION_ID
> ~~~
> {: .language-bash}
> 
> This information is often massive, as it contains the aggregated logs from all tasks 
> (map and reduce) of the job, which can be in the hundreds. One approach to reduce the 
> number of possible output is to comment out all non-essential lines (lines containing INFO)
>
> ~~~
> $ yarn logs -applicationId application_1505269880969_0056 | grep -v INFO
> ~~~
> {: .language-bash}
>
> We refine the information further. In a MapReduce setting, containers (often) execute the 
> same task. We can extract only message listing the Container IDs. 
>
> ~~~
> $ yarn logs -applicationId APPLICATION_ID | grep '^Container:'
> ~~~
> {: .language-bash}
>
> Looking at the previous report, we can further identify container information:
> 
> - Container: container_XXXXXX on  YYYY.palmetto.clemson.edu_ZZZZZ
>   - Container ID: container_XXXXXX
>   - Address of node where container is placed: YYYY.palmetto.clemson.edu
> 
> To request yarn to provide a more detailed log at container level, we run:
>
> ~~~
> $ yarn logs -applicationId APPLICATION_ID -containerId CONTAINER_ID --nodeAddress NODE_ADDRESS | grep -v INFO
> ~~~
> {: .language-bash}
{: .slide}

> ## Fixing the error
> 
> This error message gives us some insights into the mechanism of Hadoop MapReduce.
> - Where are the map and reduce python scripts located?
> - Where would the movies.csv file be, if the -file flag is used to upload this file?
>
> ~~~
> $ cat -n codes/avgRatingMapper04.py
> $ $ mapred streaming -input intro-to-hadoop/movielens/ratings.csv -output intro-to-hadoop/output-movielens-01 -file ./codes/avgRatingMapper04.py -mapper avgRatingMapper03.py -file ./codes/avgRatingReducer01.py -reducer avgRatingReducer01.py -file ./movielens/movies.csv
> ~~~
> {: .language-bash}
>
> Second Error: HDFS is read only. Therefore, all output directories must not have existed prior 
> to job submission. This can be resolved either by specifying a new output directory or deleting 
> the existing output directory
> 
> ~~~
> $ mapred streaming -input intro-to-hadoop/movielens/ratings.csv -output intro-to-hadoop/output-movielens-02 -file ./codes/avgRatingMapper04.py -mapper avgRatingMapper04.py -file ./codes/avgRatingReducer01.py -reducer avgRatingReducer01.py -file ./movielens/movies.csv
> $ hdfs dfs -ls intro-to-hadoop/output-movielens-02 
> $ hdfs dfs -cat intro-to-hadoop/output-movielens-02/part-00000 2>/dev/null | head -n 20
> ~~~
> {: .language-bash}
{: .slide}
    
{% include links.md %}

