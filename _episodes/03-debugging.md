---
title: "Debugging Hadoop MapReduce"
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

2. Debugging Hadoop MapReduce Jobs
Data: Movie Ratings and Recommendation

An independent movie company is looking to invest in a new movie project. With limited finance, the company wants to analyze the reaction of audiences, particularly toward various movie genres, in order to identify beneficial movie project to focus on. The company relies on data collected from a publicly available recommendation service by MovieLens. This dataset contains 24404096 ratings and 668953 tag applications across 40110 movies. These data were created by 247753 users between January 09, 1995 and January 29, 2016. This dataset was generated on October 17, 2016.

From this dataset, several analyses are possible, include the followings:

Find movies which have the highest average ratings over the years and identify the corresponding genre.
Find genres which have the highest average ratings over the years.
Find users who rate movies most frequently in order to contact them for in-depth marketing analysis.
These types of analyses, which are somewhat ambiguous, demand the ability to quickly process large amount of data in elatively short amount of time for decision support purposes. In these situations, the sizes of the data typically make analysis done on a single machine impossible and analysis done using a remote storage system impractical. For remainder of the lessons, we will learn how HDFS provides the basis to store massive amount of data and to enable the programming approach to analyze these data.

!hdfs dfs -ls -h /repository/movielens
Find movies which have the highest average ratings over the years and report their ratings and genres
Find the average ratings of all movies over the years
Sort the average ratings from highest to lowest
Report the results, augmented by genres
!hdfs dfs -ls /repository/movielens
!hdfs dfs -cat /repository/movielens/README.txt
!hdfs dfs -cat /repository/movielens/links.csv \
    2>/dev/null | head -n 5
!hdfs dfs -cat /repository/movielens/movies.csv \
    2>/dev/null | head -n 5
!hdfs dfs -cat /repository/movielens/ratings.csv \
    2>/dev/null | head -n 5
!hdfs dfs -cat /repository/movielens/tags.csv \
    2>/dev/null | head -n 5
Note:
To write a MapReduce program, you have to be able to identify the necessary (Key,Value) that can contribute to the final realization of the required results. This is the reducing phase. From this (Key,Value) pair format, you will be able to develop the mapping phase.

%%writefile codes/avgRatingMapper01.py
#!/usr/bin/env python

import sys

for oneMovie in sys.stdin:
    oneMovie = oneMovie.strip()
    ratingInfo = oneMovie.split(",")
    movieID = ratingInfo[1]
    rating = ratingInfo[2]
    print ("%s\t%s" % (movieID, rating)) 
!hdfs dfs -cat /repository/movielens/ratings.csv \
    2>/dev/null | head -n 5 | python ./codes/avgRatingMapper01.py
Do we really need the headers?
%%writefile codes/avgRatingMapper02.py
#!/usr/bin/env python

import sys

for oneMovie in sys.stdin:
    oneMovie = oneMovie.strip()
    ratingInfo = oneMovie.split(",")
    try:
        movieID = ratingInfo[1]
        rating = float(ratingInfo[2])
        print ("%s\t%s" % (movieID, rating))
    except ValueError:
        continue
!hdfs dfs -cat /repository/movielens/ratings.csv \
    2>/dev/null | head -n 5 | python ./codes/avgRatingMapper02.py
The outcome is correct. Is it useful?
Getting additional file

!mkdir movielens
!hdfs dfs -get /repository/movielens/movies.csv movielens/movies.csv
%%writefile codes/avgRatingMapper03.py
#!/usr/bin/env python

import sys
import csv

movieFile = "./movielens/movies.csv"
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
        movieTitle = movieList[ratingInfo[1]]["title"]
        movieGenre = movieList[ratingInfo[1]]["genre"]
        rating = float(ratingInfo[2])
        print ("%s\t%s\t%s" % (movieTitle, rating, movieGenre))
    except ValueError:
        continue
!hdfs dfs -cat /repository/movielens/ratings.csv \
    2>/dev/null | head -n 5 | python ./codes/avgRatingMapper03.py
Test reducer:
%%writefile codes/avgRatingReducer01.py
#!/usr/bin/env python
import sys

current_movie = None
current_rating_sum = 0
current_rating_count = 0

for line in sys.stdin:
    line = line.strip()
    movie, rating, genre = line.split("\t", 2)
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
            print ("%s\t%s\t%s" % (current_movie, rating_average, genre))    
        current_movie = movie
        current_rating_sum = rating
        current_rating_count = 1

if current_movie == movie:
    rating_average = current_rating_sum / current_rating_count
    print ("%s\t%s\t%s" % (current_movie, rating_average, genre))
!hdfs dfs -cat /repository/movielens/ratings.csv 2>/dev/null \
    | head -n 5 \
    | python ./codes/avgRatingMapper03.py \
    | sort \
    | python ./codes/avgRatingReducer01.py
Non-HDFS correctness test
!hdfs dfs -cat /repository/movielens/ratings.csv 2>/dev/null \
    | head -n 2000 \
    | python ./codes/avgRatingMapper03.py \
    | grep Matrix
!hdfs dfs -cat /repository/movielens/ratings.csv 2>/dev/null \
    | head -n 2000 \
    | python ./codes/avgRatingMapper03.py \
    | grep Matrix \
    | sort \
    | python ./codes/avgRatingReducer01.py
# Manual calculation check via python
(4.0+1.0+5.0)/3
Full execution on HDFS
!yarn jar /usr/hdp/current/hadoop-mapreduce-client/hadoop-streaming.jar \
    -input /repository/movielens/ratings.csv \
    -output intro-to-hadoop/output-movielens-01 \
    -file ./codes/avgRatingMapper03.py \
    -mapper avgRatingMapper03.py \
    -file ./codes/avgRatingReducer01.py \
    -reducer avgRatingReducer01.py \
2.1.1 First Error!!!
Go back to the first few lines of the previously and look for the INFO line Submitted application application_xxxx_xxxx. Running the logs command of yarn with the provided application ID is a straightforward way to access all available log information for that application. The syntax to view yarn log is:

! yarn logs -applicationId APPLICATION_ID
# Run the yarn view log command here
# Do not run this command in a notebook browser, it will likely crash the browser
#!yarn logs -applicationId application_1476193845089_0123
However, this information is often massive, as it contains the aggregated logs from all tasks (map and reduce) of the job, which can be in the hundreds. The example below demonstrates this problem by displaying all the possible information of a single-task MapReduce job. In this example, the log of a container has three types of log (LogType):

stderr: Error messages from the actual task execution
stdout: Print out messages if the task includes them
syslog: Logging messages from the Hadoop MapReduce operation
One approach to reduce the number of possible output is to comment out all non-essential lines (lines containing INFO)

!yarn logs -applicationId application_1505269880969_0056 | grep -v INFO
Can we refine the information further:

In a MapReduce setting, containers (often) execute the same task.
Can we extract only message listing the Container IDs?
!yarn logs -applicationId APPLICATION_ID | grep '^Container:'
!yarn logs -applicationId application_1505269880969_0056 | grep '^Container:'
Looking at the previous report, we can further identify container information:

Container: container_XXXXXX on  YYYY.palmetto.clemson.edu_ZZZZZ
Container ID: container_XXXXXX
Address of node where container is placed: YYYY.palmetto.clemson.edu
To request yarn to provide a more detailed log at container level, we run:

!yarn logs -applicationId APPLICATION_ID -containerId CONTAINER_ID --nodeAddress NODE_ADDRESS \
    | grep -v INFO
!yarn logs -applicationId application_1505269880969_0056 \
    -containerId container_e30_1505269880969_0056_01_000012 \
    --nodeAddress dsci035.palmetto.clemson.edu \
    | grep -v INFO
This error message gives us some insights into the mechanism of Hadoop MapReduce.

Where are the map and reduce python scripts located?
Where would the movies.csv file be, if the -file flag is used to upload this file?
%%writefile codes/avgRatingMapper04.py
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

for oneMovie in sys.stdin:
    oneMovie = oneMovie.strip()
    ratingInfo = oneMovie.split(",")
    try:
        movieTitle = movieList[ratingInfo[1]]["title"]
        movieGenre = movieList[ratingInfo[1]]["genre"]
        rating = float(ratingInfo[2])
        print ("%s\t%s\t%s" % (movieTitle, rating, movieGenre))
    except ValueError:
        continue
!yarn jar /usr/hdp/current/hadoop-mapreduce-client/hadoop-streaming.jar \
    -input /repository/movielens/ratings.csv \
    -output intro-to-hadoop/output-movielens-01 \
    -file ./codes/avgRatingMapper04.py \
    -mapper avgRatingMapper04.py \
    -file ./codes/avgRatingReducer01.py \
    -reducer avgRatingReducer01.py \
    -file ./movielens/movies.csv
2.1.2 Second Error!!!
HDFS is read only. Therefore, all output directories must not have existed prior to job submission
This can be resolved either by specifying a new output directory or deleting the existing output directory
!yarn jar /usr/hdp/current/hadoop-mapreduce-client/hadoop-streaming.jar \
    -input /repository/movielens/ratings.csv \
    -output intro-to-hadoop/output-movielens-02 \
    -file ./codes/avgRatingMapper04.py \
    -mapper avgRatingMapper04.py \
    -file ./codes/avgRatingReducer01.py \
    -reducer avgRatingReducer01.py \
    -file ./movielens/movies.csv
!hdfs dfs -ls intro-to-hadoop/output-movielens-02
!hdfs dfs -cat intro-to-hadoop/output-movielens-02/part-00000 \
    2>/dev/null | head -n 20
Challenge:
Modify avgRatingReducer02.py so that only movies with averaged ratings higher than 3.75 are collected
Further enhance your modification so that not only movies with averaged ratings higher than 3.75 are collected but these movies also need to be rated at least 5000 times.
%%writefile codes/avgRatingMapper04challenge.py
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

for oneMovie in sys.stdin:
    oneMovie = oneMovie.strip()
    ratingInfo = oneMovie.split(",")
    try:
        movieTitle = movieList[ratingInfo[1]]["title"]
        movieGenre = movieList[ratingInfo[1]]["genre"]
        rating = float(ratingInfo[2])
        if _________:
            print ("%s\t%s\t%s" % (movieTitle, rating, movieGenre))
    except ValueError:
        continue
!yarn jar /usr/hdp/current/hadoop-mapreduce-client/hadoop-streaming.jar \
    -input /repository/movielens/ratings.csv \
    -output intro-to-hadoop/output-movielens-challenge \
    -file ____________ \
    -mapper ___________ \
    -file ./codes/avgRatingReducer01.py \
    -reducer avgRatingReducer01.py \
    -file ./codes/movielens/movies.csv

{% include links.md %}

