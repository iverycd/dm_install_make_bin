#! /bin/bash

############打包软件软件的安装包##########

function package_install_files()
{
    echo "package the dm_install_x86......."
    gtar -zpcvf dm_install_content_x86.tar.gz dm_all_in_one/DMInstall_x86.bin
}
###########_Main_Process_#############
package_install_files