# Magento2 Deploy Scripts

Scripts to deploy Magento2 projects with Jenkins / CI Pipeline. 

Deploy scripts are based on the superb work of [@fbrnc](https://twitter.com/fbrnc) and AOE (https://github.com/AOEpeople/magento-deployscripts) for Magento 1

## How it works

1) Whole magento project is packaged into a build archive (project.tar.gz)
```
vendor/bin/build.sh -f project.tar.gz -b 3
```

2) Generated build is copied to a central storage server

3) Jenkins copies/pulls deploy.sh to remote server

4) deploy.sh is executed on remote server and initiates install.sh
```
magento2-deployscripts/deploy.sh -r /tmp/artifacts/project.tar.gz -e devbox -d -t /var/www/project/devbox/
```
5) Jenkins triggers cleanup script on remote server

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

## License

[GNU General Public License v3.0](http://choosealicense.com/licenses/gpl-3.0/)

## Author Information

 - [Tobias Schifftner](https://twitter.com/tschifftner), [ambimax® GmbH](https://www.ambimax.de)
