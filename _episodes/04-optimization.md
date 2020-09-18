---
title: "Optimizing Hadoop MapReduce"
teaching: 0
exercises: 0
questions:
- "Do we just throw compute nodes at big data?"
objectives:
- "Understand data movement during between mapping and reducing"
- "Understand the principle of data locality"
keypoints:
- "Minimize data size locally before moving data across the network."
---

> ## First optimization approach: Reduce data movement
>
> ~~~
> $ hdfs dfs -rm -r intro-to-hadoop/output-movielens-02
> $ mapred streaming -input intro-to-hadoop/movielens/ratings.csv -output intro-to-hadoop/output-movielens-02 -file ./codes/avgRatingMapper04.py -mapper avgRatingMapper04.py -file ./codes/avgRatingReducer01.py -reducer avgRatingReducer01.py -file ./movielens/movies.csv
> ~~~
> {: .language-bash}
>
> - What is being passed from Map to Reduce?
> - Can reducer do the same thing as mapper, that is, to load in external data?
> - If we load external data on the reduce side, do we need to do so on the map side?
>
> ~~~
> $ cat -n codes/avgRatingReducer02.py
> $ mapred streaming -input intro-to-hadoop/movielens/ratings.csv -output intro-to-hadoop/output-movielens-03 -file ./codes/avgRatingMapper02.py -mapper avgRatingMapper02.py -file ./codes/avgRatingReducer02.py -reducer avgRatingReducer02.py -file ./movielens/movies.csv
> ~~~
> {: .language-bash}
>
> How does the number shuffle bytes in this example compare to the previous example?
{: .slide}



> ## Second optimization approach: in-mapper reduction
>
> Find genres which have the highest average ratings over the years
>
> 
> - Baseline test:
>
> ~~~
> $ cat -n codes/avgGenreMapper01.py
> $ cat -n codes/avgGenreReducer01.py
> $ mapred streaming -input intro-to-hadoop/movielens/ratings.csv -output intro-to-hadoop/output-movielens-04 -file ./codes/avgGenreMapper01.py -mapper avgGenreMapper01.py -file ./codes/avgGenreReducer01.py -reducer avgGenreReducer01.py -file ./movielens/movies.csv
> ~~~
> {: .language-bash}
>
> 
> - Optimization through in-mapper reduction of Key/Value pairs
>
> ~~~
> $ cat -n codes/avgGenreMapper02.py
> $ cat -n codes/avgGenreReducer02.py
> $ mapred streaming -input intro-to-hadoop/movielens/ratings.csv -output intro-to-hadoop/output-movielens-05 -file ./codes/avgGenreMapper02.py -mapper avgGenreMapper02.py -file ./codes/avgGenreReducer02.py -reducer avgGenreReducer02.py -file ./movielens/movies.csv
> ~~~
> {: .language-bash}
> 
> How different are the number of shuffle bytes between the two jobs?
{: .slide}

> ## Third optimization approach: combiner function
>
> ~~~
> $ cat -n codes/avgGenreCombiner.py
> $ mapred streaming -input intro-to-hadoop/movielens/ratings.csv -output intro-to-hadoop/output-movielens-06 -file ./codes/avgGenreMapper02.py -mapper avgGenreMapper02.py -file ./codes/avgGenreReducer02.py -reducer avgGenreReducer02.py -file ./codes/avgGenreCombiner.py -combiner avgGenreCombiner.py -file ./movielens/movies.csv
> ~~~
> {: .language-bash}
{: .slide}

{% include links.md %}

