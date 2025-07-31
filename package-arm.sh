#! /bin/bash

############打包软件软件的安装包##########

function package_install_files()
{
    echo "package the dm_install_arm......."
    gtar -zpcvf dm_install_content_arm.tar.gz dm_all_in_one/DMInstall_arm.bin
}
###########_Main_Process_#############
package_install_files