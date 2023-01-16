function __mkrootfs_squashfs4()
{
    local T=$(gettop)
    kernelfs_formate=`grep CONFIG_SQUASHFS=y $T/lichee/*/.config | cut -d ":" -f 2`
    echo -e "\033[32m$kernelfs_formate\033[0m"
    if [ -z $kernelfs_formate ];then
		echo -e "\033[31mPlease run -make kernel_menuconfig- choice "squashfs" first!\033[0m"
	else
		compression=`grep ^CONFIG_KERNEL_SQUASHFS.*y$ $T/.config | awk 'NR==1{print}' | sed -r 's/.*_(.*)=.*/\1/' | tr '[A-Z]' '[a-z]'`
		if [ -n "$compression" ];then
			if [ x"$compression" == x"zlib" ];then
				local comp="gzip"
			elif [ x"$compression" == x"xz" ];then
				local comp="xz"
			elif [ x"$compression" == x"lz4" ];then
				local comp="lz4"
			fi
			$T/out/host/bin/mksquashfs4  $T/out/${TARGET_BOARD}/compile_dir/target/rootfs  $T/out/${TARGET_BOARD}/root.squashfs \
				-noappend -root-owned -comp $comp -b 256k -p '/dev d 755 0 0' -p '/dev/console c 600 0 0 5 1' -processors 1
		    rm  $T/out/${TARGET_BOARD}/rootfs.img
		    dd if=$T/out/${TARGET_BOARD}/root.squashfs of=$T/out/${TARGET_BOARD}/rootfs.img bs=128k conv=sync
		else
		    echo -e "\033[31mPlease run -make menuconfig- choice "TARGET_ROOTFS_SQUASHFS" first!\033[0m"
        fi
    fi
}

function __mkrootfs_ext4()
{
	local T=$(gettop)
    kernelfs_formate=`grep CONFIG_EXT4_FS=y $T/lichee/*/.config | cut -d ":" -f 2`
    echo -e "\033[32m$kernelfs_formate\033[0m"
    if [ -z $kernelfs_formate ];then
		echo -e "\033[31mPlease run -make kernel_menuconfig- choice "ext4fs" first!\033[0m"
	else
        if [ -f $T/.config ];then
            local rootfs_size_m=`awk -F'=' '/CONFIG_TARGET_ROOTFS_PARTSIZE/{print $2}' $T/.config`
        else
            echo -e "Please run make menuconfig first!" && return
        fi
		if [ -z $rootfs_size_m ];then
			echo -e "\033[31mPlease run -make menuconfig- choice "TARGET_ROOTFS_EXT4FS" first!\033[0m"
		else
            dd if=/dev/zero of=$T/out/${TARGET_BOARD}/root.ext4 count=$rootfs_size_m bs=1M
            $T/out/host/bin/mkfs.ext4 -b 4096 $T/out/${TARGET_BOARD}/root.ext4 -d $T/out/${TARGET_BOARD}/compile_dir/target/rootfs
            $T/out/host/bin/fsck.ext4 -pvfD $T/out/${TARGET_BOARD}/root.ext4
            rm  $T/out/${TARGET_BOARD}/rootfs.img
            dd if=$T/out/${TARGET_BOARD}/root.ext4 of=$T/out/${TARGET_BOARD}/rootfs.img bs=128k conv=sync
		fi
    fi
}

function add-prebuilts-to-rootfs()
{
    local top=$(gettop)
    [ -z "$top" ] \
        && echo "Couldn't locate the top of the tree.  Please source ./build/envsetup.sh first." \
        && return

    if [ x"$1" = x"--squashfs4" ];then
        [ -d $top/target/allwinner/${TARGET_BOARD}/prebuilts ] && {
            echo -e "\033[32mCopying prebuilt files to target ...\033[0m"
	        local tag=$top/out/${TARGET_BOARD}/compile_dir/target/rootfs/0-this-rootfs-overlay-is-top-priority
            cp -rf $top/target/allwinner/${TARGET_BOARD}/prebuilts/*  $top/out/${TARGET_BOARD}/compile_dir/target/rootfs
            [ -f $tag ] && rm -rf $tag
        }
        __mkrootfs_squashfs4
	    return
    fi

    if [ x"$1" = x"--ext4" ];then
        [ -d $top/target/allwinner/${TARGET_BOARD}/prebuilts ] && {
            echo -e "\033[32mCopying prebuilt files to target ...\033[0m"
	        local tag=$top/out/${TARGET_BOARD}/compile_dir/target/rootfs/0-this-rootfs-overlay-is-top-priority
            cp -rf $top/target/allwinner/${TARGET_BOARD}/prebuilts/*  $top/out/${TARGET_BOARD}/compile_dir/target/rootfs
            [ -f $tag ] && rm -rf $tag
        }
        __mkrootfs_ext4
	    return
    fi

    echo -e "\033[31mPlease run add-prebuilts-to-rootfs [--squashfs4|--ext4]\033[0m"
}

function prebuilts-skeleton-build-up()
{
    local top=$(gettop)
    [ -z "$top" ] \
        && echo "Couldn't locate the top of the tree.  Please source ./build/envsetup.sh first." \
        && return

	[ -z "${TARGET_BOARD}" ] \
		&& echo "Cannot get TARGET_BOARD information. Please run lunch first." \
		&& return

	local p=$T/target/allwinner/${TARGET_BOARD}/prebuilts
	local fs=$T/dl/prebuilts-rootfs-skeleton.tar.gz
	[ -d $p ] || \
	{
		if [ -f $fs ]; then
			tar xzf $fs -C $top/target/allwinner/${TARGET_BOARD}
			tree $p
		fi
	}

}

function _add-prebuilts-to-rootfs-option
{
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="--squashfs4 --ext4"
    COMPREPLY=( $(compgen -W "$opts" -- ${cur}) )
    return 0
}

complete -F _add-prebuilts-to-rootfs-option add-prebuilts-to-rootfs
