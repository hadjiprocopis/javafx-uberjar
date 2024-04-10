This demonstrates how to create an archive for distributing
your JavaFX app which will include all third-party dependencies,
including JavaFX, jars, as detected by maven and launcher scripts
for the three main OS: linux, mac and the unnamed (hint: M$).

It my contribution to the question I asked here:

  https://stackoverflow.com/questions/78279775/java-runtime-environment-jre-with-module-support/78280737#78280737

First just run this script with the target OS
of your choice (e.g. ```-t win```, multiple targets are supported)

```
bin/maven-package-the-app.sh -t win
```

It should create a zip file which it will contain all
the files necessary to run your app to the target OS
without installation of any other java dependencies.

Of course you will need that the target system has
installed a JRE supporting
```--add-modules``` directives (for example for java v17).
Be warned that the JRE provided by Oracle
supports java v8 (!!) and therefore is completely uselsess.

You can download a suitable JRE from, e.g.,:

https://adoptium.net/en-GB/temurin/releases/ 

or see the accepted answer at this question for more locations:

```
https://stackoverflow.com/questions/78279775/java-runtime-environment-jre-with-module-support
```

At the target system, unzip the distribution archive
you have just created, change dir to the ```launchers``` dir
and run the chosen launcher script:

```
sh linux.sh
```

```
win.bat
```

etc.

You should see the example app running.

The next step is to replace the ```src``` dir
of this repository with your own and adjust the ```pom.xml```
to refer to your own main class etc.

If you have your own ```pom.xml``` then you need
to add all the javafx dependencies like I have done,
at least for the target OS (see the ```<classifier>``` section
of each ```<dependency>```) you are interested.
You need also to add some maven plugins like in the example ```pom.xml```.

Run

```
bin/maven-package-the-app.sh -h
```

to see the usage.

**BONUS**

*Sourcing* the helper script

```
source bin/maven-get-classpath-and-friends.sh
```

will run your app via maven and you will need to close it.
It will parse the output of compiling and running your app.
When it finishes, you will have access to the following
variables:

arrays: CLASSPATH, MODULEPATH, MODULES
strings: CLASSPATHSTR, MODULEPATHSTR, MODULESSTR, MAINCLASSSTR, PROJECTNAMESTR, PROJECTJARSTR


Please do not bother me with silly M$-windows problems.
I am not a user.
