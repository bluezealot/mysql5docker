# mysql5docker
This is a mysql 5.0 docker image. The official docker image hasn't the old versions, so you can take advantage of this image if it is needed.

# Useage
```sh
docker run -p 3306:3306 -e MYSQL_ROOT_HOST='%' -e MYSQL_ROOT_PASSWORD=root123 mysql5:0.0.1
```
Args:
1) MYSQL_ROOT_HOST: The IP address of root user's PC.
2) MYSQL_ROOT_PASSWORD: Root user's password.
3) There is a mount point "/home/mysql/mysql5/data" , you can use it for persistence purpose.

# Cautions
As mysql isn't running under root previlege, so if you mount you folder to "/home/mysql/mysql5/data", access denied error shold happen. 
Here is the steps to meet the system previlege.
1) Create your folder.
2) Run the following command to authorise mysql image.
(This docker image is running under user 1001, group 1001.)
```sh
   chown 1001:1001 $yourfolder
```

# Aboud k8s
The content of k8s_deployment folder shows configurations that is used to deploy this image to k8s.
These ymls are used under my server environment, so they are for reference purpose.
You need to download them and modify them to match your environment before your deployment.