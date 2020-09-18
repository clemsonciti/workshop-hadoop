---
title: "Running Hadoop as a Batch Job"
teaching: 0
exercises: 0
questions:
- "Do we have to be in interactive mode?"
objectives:
- "Know how to use the template to develop Hadoop-based batch jobs"
keypoints:
- "You can deploy Hadoop as part of your workflow."
---

Integrating Hadoop job into Palmetto workflow. You need to be on `login001`. 

~~~
$ cd
$ cat -n ~/myhadoop/codes/movieAnalyzer.pbs
$ qsub ~/myhadoop/codes/movieAnalyzer.pbs
$ qstat -anu $USER
$ 
~~~
{: .language-bash}

{% include links.md %}

