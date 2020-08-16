FROM ubuntu:12.04

ARG uid=1001
ARG gid=1001
ARG basedir=mysql5

RUN addgroup --gid $gid --system mysql\
    && adduser --uid $uid --disabled-password --system --gid $gid mysql

WORKDIR /home/mysql
COPY my.cnf ./
# COPY mysql-5.0.96-linux-x86_64-glibc23.tar.gz mysql.tar.gz
RUN apt-get update &&\
    apt-get -y --no-install-recommends install ca-certificates wget && \
    wget https://downloads.mysql.com/archives/get/p/23/file/mysql-5.0.96-linux-x86_64-glibc23.tar.gz -O mysql.tar.gz && \
    mkdir $basedir && \
    tar -C $basedir -xzf mysql.tar.gz --strip-components 1 && \
    apt-get -y remove wget && \
    apt-get -y autoremove && \
    apt-get clean
USER mysql
RUN rm ~/mysql.tar.gz
WORKDIR $basedir
COPY mysql_dockerEntrypoint.sh mysql_dockerEntrypoint.sh
USER root
RUN chmod 777 mysql_dockerEntrypoint.sh
RUN chown -R $uid:$gid ../
RUN chmod -R 777 ../
USER mysql
EXPOSE 3306
VOLUME $basedir/data
ENTRYPOINT ["./mysql_dockerEntrypoint.sh"]
CMD ["bin/mysqld_safe"]
