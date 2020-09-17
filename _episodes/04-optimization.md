---
title: "Optimizing Hadoop MapReduce"
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

Optimization
First principle of optimizing Hadoop workflow: Reduce data movement in the shuffle phase

!hdfs dfs -rm -r intro-to-hadoop/output-movielens-02
!yarn jar /usr/hdp/current/hadoop-mapreduce-client/hadoop-streaming.jar \
    -input /repository/movielens/ratings.csv \
    -output intro-to-hadoop/output-movielens-02 \
    -file ./codes/avgRatingMapper04.py \
    -mapper avgRatingMapper04.py \
    -file ./codes/avgRatingReducer01.py \
    -reducer avgRatingReducer01.py \
    -file ./movielens/movies.csv
What is being passed from Map to Reduce?
Can reducer do the same thing as mapper, that is, to load in external data?
If we load external data on the reduce side, do we need to do so on the map side?
%%writefile codes/avgRatingReducer02.py
#!/usr/bin/env python
import sys
import csv

movieFile = "./movies.csv"
movieList = {}

with open(movieFile, mode = 'r') as infile:
    reader = csv.reader(infile)
    for row in reader:
        movieList[row[0]] = {}
        movieList[row[0]]["title"] = row[1]
        movieList[row[0]]["genre"] = row[2]

current_movie = None
current_rating_sum = 0
current_rating_count = 0

for line in sys.stdin:
    line = line.strip()
    movie, rating = line.split("\t", 1)
    try:
        rating = float(rating)
    except ValueError:
        continue

    if current_movie == movie:
        current_rating_sum += rating
        current_rating_count += 1
    else:
        if current_movie:
            rating_average = current_rating_sum / current_rating_count
            movieTitle = movieList[current_movie]["title"]
            movieGenres = movieList[current_movie]["genre"]
            print ("%s\t%s\t%s" % (movieTitle, rating_average, movieGenres))    
        current_movie = movie
        current_rating_sum = rating
        current_rating_count = 1

if current_movie == movie:
    rating_average = current_rating_sum / current_rating_count
    movieTitle = movieList[current_movie]["title"]
    movieGenres = movieList[current_movie]["genre"]
    print ("%s\t%s\t%s" % (movieTitle, rating_average, movieGenres))
!hdfs dfs -rm -r intro-to-hadoop/output-movielens-03
!yarn jar /usr/hdp/current/hadoop-mapreduce-client/hadoop-streaming.jar \
    -input /repository/movielens/ratings.csv \
    -output intro-to-hadoop/output-movielens-03 \
    -file ./codes/avgRatingMapper02.py \
    -mapper avgRatingMapper02.py \
    -file ./codes/avgRatingReducer02.py \
    -reducer avgRatingReducer02.py \
    -file ./movielens/movies.csv
!hdfs dfs -ls intro-to-hadoop/output-movielens-02
!hdfs dfs -ls intro-to-hadoop/output-movielens-03
!hdfs dfs -cat intro-to-hadoop/output-movielens-03/part-00000 \
    2>/dev/null | head -n 10
How does the number shuffle bytes in this example compare to the previous example?

Find genres which have the highest average ratings over the years
Common optimization approaches:

In-mapper reduction of key/value pairs
Additional combiner function
%%writefile codes/avgGenreMapper01.py
#!/usr/bin/env python
import sys
import csv

# for nonHDFS run
movieFile = "./movielens/movies.csv"

# for HDFS run
#movieFile = "./movies.csv"
movieList = {}

with open(movieFile, mode = 'r') as infile:
    reader = csv.reader(infile)
    for row in reader:
        movieList[row[0]] = {}
        movieList[row[0]]["title"] = row[1]
        movieList[row[0]]["genre"] = row[2]

for oneMovie in sys.stdin:
    oneMovie = oneMovie.strip()
    ratingInfo = oneMovie.split(",")
    try:
        genreList = movieList[ratingInfo[1]]["genre"]
        rating = float(ratingInfo[2])
        for genre in genreList.split("|"):
            print ("%s\t%s" % (genre, rating))
    except ValueError:
        continue
%%writefile codes/avgGenreReducer01.py
#!/usr/bin/env python
import sys
import csv
import json

current_genre = None
current_rating_sum = 0
current_rating_count = 0

for line in sys.stdin:
    line = line.strip()
    genre, rating = line.split("\t", 1)

    if current_genre == genre:
        try:
            current_rating_sum += float(rating)
            current_rating_count += 1
        except ValueError:
            continue    
    else:
        if current_genre:
            rating_average = current_rating_sum / current_rating_count
            print ("%s\t%s" % (current_genre, rating_average))    
        current_genre = genre
        try:
            current_rating_sum = float(rating)
            current_rating_count = 1
        except ValueError:
            continue

if current_genre == genre:
    rating_average = current_rating_sum / current_rating_count
    print ("%s\t%s" % (current_genre, rating_average))
!hdfs dfs -rm -r intro-to-hadoop/output-movielens-04
!yarn jar /usr/hdp/current/hadoop-mapreduce-client/hadoop-streaming.jar \
    -input /repository/movielens/ratings.csv \
    -output intro-to-hadoop/output-movielens-04 \
    -file ./codes/avgGenreMapper01.py \
    -mapper avgGenreMapper01.py \
    -file ./codes/avgGenreReducer01.py \
    -reducer avgGenreReducer01.py \
    -file ./movielens/movies.csv
!hdfs dfs -ls intro-to-hadoop/output-movielens-04
!hdfs dfs -cat intro-to-hadoop/output-movielens-04/part-00000
2.2.1 Optimization through in-mapper reduction of Key/Value pairs
!hdfs dfs -cat /repository/movielens/ratings.csv 2>/dev/null \
    | head -n 10
!hdfs dfs -cat /repository/movielens/ratings.csv 2>/dev/null \
    | head -n 10 \
    | python ./codes/avgGenreMapper01.py \
%%writefile codes/avgGenreMapper02.py
#!/usr/bin/env python

import sys
import csv
import json

# for nonHDFS run
# movieFile = "./movielens/movies.csv"

# for HDFS run
movieFile = "./movies.csv"

movieList = {}
genreList = {}

with open(movieFile, mode = 'r') as infile:
    reader = csv.reader(infile)
    for row in reader:
        movieList[row[0]] = {}
        movieList[row[0]]["title"] = row[1]
        movieList[row[0]]["genre"] = row[2]

for oneMovie in sys.stdin:
    oneMovie = oneMovie.strip()
    ratingInfo = oneMovie.split(",")
    try:
        genres = movieList[ratingInfo[1]]["genre"]
        rating = float(ratingInfo[2])
        for genre in genres.split("|"):
            if genre in genreList:
                genreList[genre]["total_rating"] += rating
                genreList[genre]["total_count"] += 1
            else:
                genreList[genre] = {}
                genreList[genre]["total_rating"] = rating
                genreList[genre]["total_count"] = 1
    except ValueError:
        continue
        
for genre in genreList:
    print ("%s\t%s" % (genre, json.dumps(genreList[genre])))
!hdfs dfs -cat /repository/movielens/ratings.csv 2>/dev/null \
    | head -n 10 \
    | python ./codes/avgGenreMapper02.py \
%%writefile codes/avgGenreReducer02.py
#!/usr/bin/env python
import sys
import csv
import json

current_genre = None
current_rating_sum = 0
current_rating_count = 0

for line in sys.stdin:
    line = line.strip()
    genre, ratingString = line.split("\t", 1)
    ratingInfo = json.loads(ratingString)

    if current_genre == genre:
        try:
            current_rating_sum += ratingInfo["total_rating"]
            current_rating_count += ratingInfo["total_count"]
        except ValueError:
            continue    
    else:
        if current_genre:
            rating_average = current_rating_sum / current_rating_count
            print ("%s\t%s" % (current_genre, rating_average))    
        current_genre = genre
        try:
            current_rating_sum = ratingInfo["total_rating"]
            current_rating_count = ratingInfo["total_count"]
        except ValueError:
            continue

if current_genre == genre:
    rating_average = current_rating_sum / current_rating_count
    print ("%s\t%s" % (current_genre, rating_average))
!hdfs dfs -cat /repository/movielens/ratings.csv 2>/dev/null \
    | head -n 10 \
    | python ./codes/avgGenreMapper02.py \
    | sort \
    | python ./codes/avgGenreReducer02.py
# make sure that the path to movies.csv is correct inside avgGenreMapper02.py
!hdfs dfs -rm -R intro-to-hadoop/output-movielens-05
!yarn jar /usr/hdp/current/hadoop-mapreduce-client/hadoop-streaming.jar \
    -input /repository/movielens/ratings.csv \
    -output intro-to-hadoop/output-movielens-05 \
    -file ./codes/avgGenreMapper02.py \
    -mapper avgGenreMapper02.py \
    -file ./codes/avgGenreReducer02.py \
    -reducer avgGenreReducer02.py \
    -file ./movielens/movies.csv
!hdfs dfs -cat intro-to-hadoop/output-movielens-05/part-00000
!hdfs dfs -cat intro-to-hadoop/output-movielens-04/part-00000
How different are the number of shuffle bytes between the two jobs?

2.2.2 Optimization through combiner function
!hdfs dfs -ls /repository/
Found 16 items
-rw-r--r--   2 lngo   hdfs-user       1034 2016-11-18 08:04 /repository/.pysparkrc
drwxr-xr-x   - lngo   hdfs-user          0 2017-09-14 09:23 /repository/airlines
-rw-r--r--   2 lngo   hdfs-user 2383967007 2016-11-29 21:31 /repository/bigdata-workshop.tgz
drwxr-xr-x   - denton hdfs-user          0 2017-10-11 09:15 /repository/chicago_data
-rw-r--r--   2 lngo   hdfs-user    5590193 2016-03-22 14:09 /repository/complete-shakespeare.txt
drwxr-xr-x   - denton hdfs-user          0 2016-11-02 08:16 /repository/cypress-pyspark-kernel
drwxr-xr-x   - lngo   hdfs-user          0 2016-02-03 10:17 /repository/gtrace
drwxr-xr-x   - lngo   hdfs-user          0 2017-05-23 08:40 /repository/halvade
-rw-r--r--   2 lngo   hdfs-user 2580196770 2017-03-16 06:02 /repository/intro-to-hadoop.tgz
-rw-r--r--   2 denton hdfs-user      34590 2016-12-01 09:31 /repository/intro-to-pyspark.ipynb
-rw-r--r--   2 lngo   hdfs-user 2775356893 2017-04-04 14:55 /repository/intro-to-spark-palmetto.tgz
-rw-r--r--   2 lngo   hdfs-user 2502932465 2016-11-01 15:47 /repository/intro-to-spark.tgz
-rw-r--r--   2 lngo   hdfs-user  294155091 2017-03-23 09:14 /repository/intro-to-sparkr.tgz
drwxr-xr-x   - lngo   hdfs-user          0 2017-03-15 09:49 /repository/movielens
-rw-r--r--   2 lngo   hdfs-user  620204630 2016-11-30 11:16 /repository/ratings.csv
drwxr-xr-x   - lngo   hdfs-user          0 2016-02-24 18:58 /repository/reddit
!yarn jar /usr/hdp/current/hadoop-mapreduce-client/hadoop-streaming.jar \
    -input /repository/complete-shakespeare.txt \
    -output intro-to-hadoop/output-wordcount-01 \
    -file ./codes/wordcountMapper.py \
    -mapper wordcountMapper.py \
    -file ./codes/wordcountReducer.py \
    -reducer wordcountReducer.py
17/10/11 12:22:53 WARN streaming.StreamJob: -file option is deprecated, please use generic option -files instead.
packageJobJar: [./codes/wordcountMapper.py, ./codes/wordcountReducer.py] [/usr/hdp/2.6.0.3-8/hadoop-mapreduce/hadoop-streaming-2.7.3.2.6.0.3-8.jar] /hadoop_java_io_tmpdir/streamjob2064724442186879809.jar tmpDir=null
17/10/11 12:22:55 INFO client.AHSProxy: Connecting to Application History server at dscim003.palmetto.clemson.edu/10.125.8.215:10200
17/10/11 12:22:55 INFO client.AHSProxy: Connecting to Application History server at dscim003.palmetto.clemson.edu/10.125.8.215:10200
17/10/11 12:22:55 INFO hdfs.DFSClient: Created HDFS_DELEGATION_TOKEN token 14512 for lngo on ha-hdfs:dsci
17/10/11 12:22:55 INFO security.TokenCache: Got dt for hdfs://dsci; Kind: HDFS_DELEGATION_TOKEN, Service: ha-hdfs:dsci, Ident: (HDFS_DELEGATION_TOKEN token 14512 for lngo)
17/10/11 12:22:56 INFO lzo.GPLNativeCodeLoader: Loaded native gpl library
17/10/11 12:22:56 INFO lzo.LzoCodec: Successfully loaded & initialized native-lzo library [hadoop-lzo rev 8787857212dae53ffae3b3113abc894e6743b4ab]
17/10/11 12:22:56 INFO mapred.FileInputFormat: Total input paths to process : 1
17/10/11 12:22:56 INFO mapreduce.JobSubmitter: number of splits:2
17/10/11 12:22:56 INFO mapreduce.JobSubmitter: Submitting tokens for job: job_1505269880969_0213
17/10/11 12:22:56 INFO mapreduce.JobSubmitter: Kind: HDFS_DELEGATION_TOKEN, Service: ha-hdfs:dsci, Ident: (HDFS_DELEGATION_TOKEN token 14512 for lngo)
17/10/11 12:22:57 INFO impl.TimelineClientImpl: Timeline service address: http://dscim003.palmetto.clemson.edu:8188/ws/v1/timeline/
17/10/11 12:22:57 INFO impl.YarnClientImpl: Submitted application application_1505269880969_0213
17/10/11 12:22:57 INFO mapreduce.Job: The url to track the job: http://dscim001.palmetto.clemson.edu:8088/proxy/application_1505269880969_0213/
17/10/11 12:22:57 INFO mapreduce.Job: Running job: job_1505269880969_0213
17/10/11 12:23:08 INFO mapreduce.Job: Job job_1505269880969_0213 running in uber mode : false
17/10/11 12:23:08 INFO mapreduce.Job:  map 0% reduce 0%
17/10/11 12:23:15 INFO mapreduce.Job:  map 50% reduce 0%
17/10/11 12:23:19 INFO mapreduce.Job:  map 100% reduce 0%
17/10/11 12:23:26 INFO mapreduce.Job:  map 100% reduce 100%
17/10/11 12:23:26 INFO mapreduce.Job: Job job_1505269880969_0213 completed successfully
17/10/11 12:23:26 INFO mapreduce.Job: Counters: 50
	File System Counters
		FILE: Number of bytes read=8575076
		FILE: Number of bytes written=17639352
		FILE: Number of read operations=0
		FILE: Number of large read operations=0
		FILE: Number of write operations=0
		HDFS: Number of bytes read=5678879
		HDFS: Number of bytes written=721220
		HDFS: Number of read operations=9
		HDFS: Number of large read operations=0
		HDFS: Number of write operations=2
	Job Counters 
		Killed map tasks=1
		Launched map tasks=2
		Launched reduce tasks=1
		Rack-local map tasks=2
		Total time spent by all maps in occupied slots (ms)=42006
		Total time spent by all reduces in occupied slots (ms)=23682
		Total time spent by all map tasks (ms)=14002
		Total time spent by all reduce tasks (ms)=7894
		Total vcore-milliseconds taken by all map tasks=14002
		Total vcore-milliseconds taken by all reduce tasks=7894
		Total megabyte-milliseconds taken by all map tasks=180513784
		Total megabyte-milliseconds taken by all reduce tasks=101769448
	Map-Reduce Framework
		Map input records=124796
		Map output records=904087
		Map output bytes=6766896
		Map output materialized bytes=8575082
		Input split bytes=198
		Combine input records=0
		Combine output records=0
		Reduce input groups=67799
		Reduce shuffle bytes=8575082
		Reduce input records=904087
		Reduce output records=67799
		Spilled Records=1808174
		Shuffled Maps =2
		Failed Shuffles=0
		Merged Map outputs=2
		GC time elapsed (ms)=228
		CPU time spent (ms)=10080
		Physical memory (bytes) snapshot=4022095872
		Virtual memory (bytes) snapshot=39908544512
		Total committed heap usage (bytes)=4083154944
	Shuffle Errors
		BAD_ID=0
		CONNECTION=0
		IO_ERROR=0
		WRONG_LENGTH=0
		WRONG_MAP=0
		WRONG_REDUCE=0
	File Input Format Counters 
		Bytes Read=5678681
	File Output Format Counters 
		Bytes Written=721220
17/10/11 12:23:26 INFO streaming.StreamJob: Output directory: intro-to-hadoop/output-wordcount-01
!yarn jar /usr/hdp/current/hadoop-mapreduce-client/hadoop-streaming.jar \
    -input /repository/complete-shakespeare.txt \
    -output intro-to-hadoop/output-wordcount-02 \
    -file ./codes/wordcountMapper.py \
    -mapper wordcountMapper.py \
    -file ./codes/wordcountReducer.py \
    -reducer wordcountReducer.py \
    -combiner wordcountReducer.py
17/10/11 12:23:28 WARN streaming.StreamJob: -file option is deprecated, please use generic option -files instead.
packageJobJar: [./codes/wordcountMapper.py, ./codes/wordcountReducer.py] [/usr/hdp/2.6.0.3-8/hadoop-mapreduce/hadoop-streaming-2.7.3.2.6.0.3-8.jar] /hadoop_java_io_tmpdir/streamjob3330378274220223963.jar tmpDir=null
17/10/11 12:23:29 INFO client.AHSProxy: Connecting to Application History server at dscim003.palmetto.clemson.edu/10.125.8.215:10200
17/10/11 12:23:30 INFO client.AHSProxy: Connecting to Application History server at dscim003.palmetto.clemson.edu/10.125.8.215:10200
17/10/11 12:23:30 INFO hdfs.DFSClient: Created HDFS_DELEGATION_TOKEN token 14515 for lngo on ha-hdfs:dsci
17/10/11 12:23:30 INFO security.TokenCache: Got dt for hdfs://dsci; Kind: HDFS_DELEGATION_TOKEN, Service: ha-hdfs:dsci, Ident: (HDFS_DELEGATION_TOKEN token 14515 for lngo)
17/10/11 12:23:30 INFO lzo.GPLNativeCodeLoader: Loaded native gpl library
17/10/11 12:23:30 INFO lzo.LzoCodec: Successfully loaded & initialized native-lzo library [hadoop-lzo rev 8787857212dae53ffae3b3113abc894e6743b4ab]
17/10/11 12:23:30 INFO mapred.FileInputFormat: Total input paths to process : 1
17/10/11 12:23:30 INFO mapreduce.JobSubmitter: number of splits:2
17/10/11 12:23:31 INFO mapreduce.JobSubmitter: Submitting tokens for job: job_1505269880969_0216
17/10/11 12:23:31 INFO mapreduce.JobSubmitter: Kind: HDFS_DELEGATION_TOKEN, Service: ha-hdfs:dsci, Ident: (HDFS_DELEGATION_TOKEN token 14515 for lngo)
17/10/11 12:23:31 INFO impl.TimelineClientImpl: Timeline service address: http://dscim003.palmetto.clemson.edu:8188/ws/v1/timeline/
17/10/11 12:23:31 INFO impl.YarnClientImpl: Submitted application application_1505269880969_0216
17/10/11 12:23:31 INFO mapreduce.Job: The url to track the job: http://dscim001.palmetto.clemson.edu:8088/proxy/application_1505269880969_0216/
17/10/11 12:23:31 INFO mapreduce.Job: Running job: job_1505269880969_0216
17/10/11 12:23:38 INFO mapreduce.Job: Job job_1505269880969_0216 running in uber mode : false
17/10/11 12:23:38 INFO mapreduce.Job:  map 0% reduce 0%
17/10/11 12:23:46 INFO mapreduce.Job:  map 100% reduce 0%
17/10/11 12:23:52 INFO mapreduce.Job:  map 100% reduce 100%
17/10/11 12:23:52 INFO mapreduce.Job: Job job_1505269880969_0216 completed successfully
17/10/11 12:23:52 INFO mapreduce.Job: Counters: 49
	File System Counters
		FILE: Number of bytes read=1105615
		FILE: Number of bytes written=2701408
		FILE: Number of read operations=0
		FILE: Number of large read operations=0
		FILE: Number of write operations=0
		HDFS: Number of bytes read=5678879
		HDFS: Number of bytes written=717253
		HDFS: Number of read operations=9
		HDFS: Number of large read operations=0
		HDFS: Number of write operations=2
	Job Counters 
		Launched map tasks=2
		Launched reduce tasks=1
		Rack-local map tasks=2
		Total time spent by all maps in occupied slots (ms)=32610
		Total time spent by all reduces in occupied slots (ms)=11886
		Total time spent by all map tasks (ms)=10870
		Total time spent by all reduce tasks (ms)=3962
		Total vcore-milliseconds taken by all map tasks=10870
		Total vcore-milliseconds taken by all reduce tasks=3962
		Total megabyte-milliseconds taken by all map tasks=140136040
		Total megabyte-milliseconds taken by all reduce tasks=51078104
	Map-Reduce Framework
		Map input records=124796
		Map output records=904087
		Map output bytes=6766896
		Map output materialized bytes=1105621
		Input split bytes=198
		Combine input records=904087
		Combine output records=89121
		Reduce input groups=67799
		Reduce shuffle bytes=1105621
		Reduce input records=89121
		Reduce output records=67799
		Spilled Records=178242
		Shuffled Maps =2
		Failed Shuffles=0
		Merged Map outputs=2
		GC time elapsed (ms)=160
		CPU time spent (ms)=9020
		Physical memory (bytes) snapshot=5466710016
		Virtual memory (bytes) snapshot=39907373056
		Total committed heap usage (bytes)=5898764288
	Shuffle Errors
		BAD_ID=0
		CONNECTION=0
		IO_ERROR=0
		WRONG_LENGTH=0
		WRONG_MAP=0
		WRONG_REDUCE=0
	File Input Format Counters 
		Bytes Read=5678681
	File Output Format Counters 
		Bytes Written=717253
17/10/11 12:23:52 INFO streaming.StreamJob: Output directory: intro-to-hadoop/output-wordcount-02
%%writefile codes/avgGenreCombiner.py
#!/usr/bin/env python

import sys
import csv
import json

genreList = {}

for line in sys.stdin:
    line = line.strip()
    genre, ratingString = line.split("\t", 1)
    ratingInfo = json.loads(ratingString)

    if genre in genreList:
        genreList[genre]["total_rating"] += ratingInfo["total_rating"]
        genreList[genre]["total_count"] += ratingInfo["total_count"]
    else:
        genreList[genre] = {}
        genreList[genre]["total_rating"] = ratingInfo["total_rating"]
        genreList[genre]["total_count"] = 1

for genre in genreList:
    print ("%s\t%s" % (genre, json.dumps(genreList[genre])))
Overwriting codes/avgGenreCombiner.py
!hdfs dfs -rm -r intro-to-hadoop/output-movielens-06
!yarn jar /usr/hdp/current/hadoop-mapreduce-client/hadoop-streaming.jar \
    -input /repository/movielens/ratings.csv \
    -output intro-to-hadoop/output-movielens-06 \
    -file ./codes/avgGenreMapper02.py \
    -mapper avgGenreMapper02.py \
    -file ./codes/avgGenreReducer02.py \
    -reducer avgGenreReducer02.py \
    -file ./codes/avgGenreCombiner.py \
    -combiner avgGenreCombiner.py \
    -file ./movielens/movies.csv
17/10/11 12:28:37 INFO fs.TrashPolicyDefault: Moved: 'hdfs://dsci/user/lngo/intro-to-hadoop/output-movielens-06' to trash at: hdfs://dsci/user/lngo/.Trash/Current/user/lngo/intro-to-hadoop/output-movielens-06
17/10/11 12:28:39 WARN streaming.StreamJob: -file option is deprecated, please use generic option -files instead.
packageJobJar: [./codes/avgGenreMapper02.py, ./codes/avgGenreReducer02.py, ./codes/avgGenreCombiner.py, ./movielens/movies.csv] [/usr/hdp/2.6.0.3-8/hadoop-mapreduce/hadoop-streaming-2.7.3.2.6.0.3-8.jar] /hadoop_java_io_tmpdir/streamjob706582146786084890.jar tmpDir=null
17/10/11 12:28:40 INFO client.AHSProxy: Connecting to Application History server at dscim003.palmetto.clemson.edu/10.125.8.215:10200
17/10/11 12:28:40 INFO client.AHSProxy: Connecting to Application History server at dscim003.palmetto.clemson.edu/10.125.8.215:10200
17/10/11 12:28:41 INFO hdfs.DFSClient: Created HDFS_DELEGATION_TOKEN token 14539 for lngo on ha-hdfs:dsci
17/10/11 12:28:41 INFO security.TokenCache: Got dt for hdfs://dsci; Kind: HDFS_DELEGATION_TOKEN, Service: ha-hdfs:dsci, Ident: (HDFS_DELEGATION_TOKEN token 14539 for lngo)
17/10/11 12:28:41 INFO lzo.GPLNativeCodeLoader: Loaded native gpl library
17/10/11 12:28:41 INFO lzo.LzoCodec: Successfully loaded & initialized native-lzo library [hadoop-lzo rev 8787857212dae53ffae3b3113abc894e6743b4ab]
17/10/11 12:28:41 INFO mapred.FileInputFormat: Total input paths to process : 1
17/10/11 12:28:41 INFO mapreduce.JobSubmitter: number of splits:5
17/10/11 12:28:41 INFO mapreduce.JobSubmitter: Submitting tokens for job: job_1505269880969_0238
17/10/11 12:28:41 INFO mapreduce.JobSubmitter: Kind: HDFS_DELEGATION_TOKEN, Service: ha-hdfs:dsci, Ident: (HDFS_DELEGATION_TOKEN token 14539 for lngo)
17/10/11 12:28:42 INFO impl.TimelineClientImpl: Timeline service address: http://dscim003.palmetto.clemson.edu:8188/ws/v1/timeline/
17/10/11 12:28:42 INFO impl.YarnClientImpl: Submitted application application_1505269880969_0238
17/10/11 12:28:42 INFO mapreduce.Job: The url to track the job: http://dscim001.palmetto.clemson.edu:8088/proxy/application_1505269880969_0238/
17/10/11 12:28:42 INFO mapreduce.Job: Running job: job_1505269880969_0238
17/10/11 12:28:48 INFO mapreduce.Job: Job job_1505269880969_0238 running in uber mode : false
17/10/11 12:28:48 INFO mapreduce.Job:  map 0% reduce 0%
17/10/11 12:29:01 INFO mapreduce.Job:  map 23% reduce 0%
17/10/11 12:29:02 INFO mapreduce.Job:  map 30% reduce 0%
17/10/11 12:29:04 INFO mapreduce.Job:  map 39% reduce 0%
17/10/11 12:29:05 INFO mapreduce.Job:  map 45% reduce 0%
17/10/11 12:29:07 INFO mapreduce.Job:  map 62% reduce 0%
17/10/11 12:29:08 INFO mapreduce.Job:  map 83% reduce 0%
17/10/11 12:29:09 INFO mapreduce.Job:  map 91% reduce 0%
17/10/11 12:29:10 INFO mapreduce.Job:  map 100% reduce 0%
17/10/11 12:29:13 INFO mapreduce.Job:  map 100% reduce 100%
17/10/11 12:29:13 INFO mapreduce.Job: Job job_1505269880969_0238 completed successfully
17/10/11 12:29:13 INFO mapreduce.Job: Counters: 51
	File System Counters
		FILE: Number of bytes read=5603
		FILE: Number of bytes written=995397
		FILE: Number of read operations=0
		FILE: Number of large read operations=0
		FILE: Number of write operations=0
		HDFS: Number of bytes read=663945432
		HDFS: Number of bytes written=1653
		HDFS: Number of read operations=18
		HDFS: Number of large read operations=0
		HDFS: Number of write operations=2
	Job Counters 
		Killed map tasks=1
		Launched map tasks=6
		Launched reduce tasks=1
		Data-local map tasks=2
		Rack-local map tasks=4
		Total time spent by all maps in occupied slots (ms)=258180
		Total time spent by all reduces in occupied slots (ms)=11277
		Total time spent by all map tasks (ms)=86060
		Total time spent by all reduce tasks (ms)=3759
		Total vcore-milliseconds taken by all map tasks=86060
		Total vcore-milliseconds taken by all reduce tasks=3759
		Total megabyte-milliseconds taken by all map tasks=1109485520
		Total megabyte-milliseconds taken by all reduce tasks=48461028
	Map-Reduce Framework
		Map input records=24404097
		Map output records=100
		Map output bytes=5899
		Map output materialized bytes=5627
		Input split bytes=480
		Combine input records=100
		Combine output records=100
		Reduce input groups=92
		Reduce shuffle bytes=5627
		Reduce input records=100
		Reduce output records=92
		Spilled Records=200
		Shuffled Maps =5
		Failed Shuffles=0
		Merged Map outputs=5
		GC time elapsed (ms)=3269
		CPU time spent (ms)=144870
		Physical memory (bytes) snapshot=14061768704
		Virtual memory (bytes) snapshot=79764459520
		Total committed heap usage (bytes)=15988686848
	Shuffle Errors
		BAD_ID=0
		CONNECTION=0
		IO_ERROR=0
		WRONG_LENGTH=0
		WRONG_MAP=0
		WRONG_REDUCE=0
	File Input Format Counters 
		Bytes Read=663944952
	File Output Format Counters 
		Bytes Written=1653
17/10/11 12:29:13 INFO streaming.StreamJob: Output directory: intro-to-hadoop/output-movielens-06
{% include links.md %}

