#!/bin/sh

CONFIGURE_FLAGS="--enable-static --enable-pic --disable-cli --disable-asm"

ARCHS="arm64 armv7s x86_64 i386 armv7"

# directories
SOURCE="x264"
FAT="x264-iOS"

SCRATCH="scratch-x264"
# must be an absolute path
THIN=`pwd`/"thin-x264"

# the one included in x264 does not work; specify full path to working one
GAS_PREPROCESSOR=/usr/local/bin/gas-preprocessor.pl

COMPILE="y"
LIPO="y"
FRAMEWORK="y"
DEPLOYMENT_TARGET="7.0"

if [ "$*" ]
then
	if [ "$*" = "lipo" ]
	then
		# skip compile
		COMPILE=
	else
		ARCHS="$*"
		if [ $# -eq 1 ]
		then
			# skip lipo
			LIPO=
		fi
	fi
fi

if [ "$COMPILE" ]
then
	if [ ! -r $SOURCE ]
	then
		echo 'x264 source not found. Trying to download...'
		#curl https://download.videolan.org/pub/x264/snapshots/x264-snapshot-20140930-2245.tar.bz2 | tar xj && ln -s x264-snapshot-20140930-2245 x264 || exit 1
        git clone https://github.com/Diveinedu-CN/x264.git && pushd x264 && git checkout diveinedu && popd;
	fi

	CWD=`pwd`
	for ARCH in $ARCHS
	do
		echo "building $ARCH..."
		mkdir -p "$SCRATCH/$ARCH"
		cd "$SCRATCH/$ARCH"

		if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
		then
		    PLATFORM="iPhoneSimulator"
		    CFLAGS="$CFLAGS -mios-simulator-version-min=$DEPLOYMENT_TARGET"
		    CPU=
		    if [ "$ARCH" = "x86_64" ]
		    then
		    	HOST=
		    else
		    	HOST="--host=i386-apple-darwin"
		    fi
		else
		    PLATFORM="iPhoneOS"
		    CFLAGS="$CFLAGS -mios-version-min=$DEPLOYMENT_TARGET"
		    if [ $ARCH = "armv7s" ]
		    then
		    	CPU="--cpu=swift"
		    else
		    	CPU=
		    fi
		    SIMULATOR=
		    if [ $ARCH = "arm64" ]
		    then
		        HOST="--host=aarch64-apple-darwin"
		        #CPU="--disable-asm"
		    else
		        HOST="--host=arm-apple-darwin"
		    fi
		fi

		XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
		CC="xcrun -sdk $XCRUN_SDK clang -Wno-error=unused-command-line-argument-hard-error-in-future -arch $ARCH"
		CFLAGS="-arch $ARCH $SIMULATOR -fembed-bitcode"
		CXXFLAGS="$CFLAGS"
		LDFLAGS="$CFLAGS"

		CC=$CC $CWD/$SOURCE/configure \
		    $CONFIGURE_FLAGS \
		    $HOST \
		    $CPU \
		    --extra-cflags="$CFLAGS" \
		    --extra-ldflags="$LDFLAGS" \
		    --prefix="$THIN/$ARCH"

		mkdir extras
		ln -s $GAS_PREPROCESSOR extras

		make -j2 install
		cd $CWD
	done
fi

if [ "$LIPO" ]
then
	echo "building fat binaries..."
	mkdir -p $FAT/lib
	set - $ARCHS
	CWD=`pwd`
	cd $THIN/$1/lib
	for LIB in *.a
	do
		cd $CWD
		lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB
	done

	cd $CWD
	cp -rf $THIN/$1/include $FAT
fi

if [ "$FRAMEWORK" ]
then
	echo "building x264 framework..."
	CWD=`pwd`
	cd $FAT
	mkdir -p "x264.framework/Headers"
	cp lib/libx264.a x264.framework/x264
	cp include/*  x264.framework/Headers
	cd $CWD
fi

rm -rf $SCRATCH $THIN
