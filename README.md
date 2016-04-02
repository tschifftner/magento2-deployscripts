# Magento2 Deploy Scripts

**_--- THIS IS IN DEVELOPMENT ---_** 

Deploy scripts are based on the superb work of [@fbrnc](https://twitter.com/fbrnc) and AOE (https://github.com/AOEpeople/magento-deployscripts) for Magento 1

## How it works

1) Whole magento project is packaged into a build archive (project.tar.gz)
2) Generated build is copied to a central storage server
3) Jenkins copies deploy.sh to remote server
4) deploy.sh is executed on remote server and initiates install.sh
5) Jenkins triggers cleanup script on remote server

### ToDo

- New way to apply settings for dev,staging,live,etc
