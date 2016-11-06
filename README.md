# Magento2 Deploy Scripts

Scripts to deploy Magento2 projects with Jenkins / CI Pipeline. This includes packaging the project and deploying it while setting all required variables for database, environment, etc.

Deploy scripts are based on the superb work of [@fbrnc](https://twitter.com/fbrnc) and AOE (https://github.com/AOEpeople/magento-deployscripts) for Magento 1

## How deployment works

1) Whole Magento project is packaged into an build archive (project.tar.gz)

2) Generated build archive is copied to a central storage server

3) Deploy scripts are cloned for deployment on staging/production server

4) deploy.sh is executed, downloads and unpacks package.tar.gz and runs install.sh

```
magento2-deployscripts/deploy.sh -r /tmp/artifacts/project.tar.gz -e devbox -d -t /var/www/project/devbox/
```

5) install.sh sets database and environment variables

6) Cleanup of older releases

## Defining settings with zettr.phar

Define configuration in config/settings.csv regarding the
zettr documentation

 - Environment Settings
 - Database updates
 - XmlFile configuration
 

## Installation

Add this package to your Magento composer.json:

```
"require": {
    "tschifftner/magento2-deployscripts": "dev-master"
 },
```

To use zettr with Magento2 you need to add it too (respository is required
as long as the pull request is not merged)
```
"require": {
    "aoepeople/zettr": "@dev"
 },
   "repositories": {
     "0": {
       "type": "vcs",
       "url": "https://github.com/tschifftner/zettr.git"
     }
   },
```

As there is a bug within Magento you currently require also
```
"require": {
    "tschifftner/magento2-module-tschifftner-deployhelper": "dev-master"
 },
```

## Deployment (manual or by Jenkins job)

### 1) Build package

1) Update Magento2 project source code to latest version 

2) Run shell commands:

```
bin/composer.phar update --verbose --no-ansi --no-interaction --prefer-source
vendor/tschifftner/magento2-deployscripts/build.sh -f project.tar.gz -b $BUILD_NUMBER
```

3) Archive artefacts and/or copy to central storage like sftp or s3

### 2) Deployment

Deployment for staging or production is all the same just with different variables.


1) Clone deployment scripts to accessible location

```
git clone https://github.com/tschifftner/magento2-deployscripts.git ~/deployscripts
```

2) Ensure scripts are executable
```
chmod +x ~/deployscripts/{deploy,cleanup}.sh
```

3) Deploy build package

```
# e = environment (staging,production,devbox,etc)
# r = package url
# u = user
# p = password
# t = project dir

~/deployscripts/deploy.sh -e staging -r http://storageserver.com/project.tar.gz -u 'user' -p 'password' -t /var/www/project/  || exit1
```

4) Cleanup old releases

```
~/deployscripts/cleanup.sh -r ~/releases/ || exit1
```

## License

[GNU General Public License v3.0](http://choosealicense.com/licenses/gpl-3.0/)

## Author Information

 - [Tobias Schifftner](https://twitter.com/tschifftner), [ambimax® GmbH](https://www.ambimax.de)
