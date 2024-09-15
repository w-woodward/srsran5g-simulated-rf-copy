set -ex
COMMIT_HASH=$1
SRS_TYPE=$2
BINDIR=`dirname $0`
SRCDIR=/opt
TMPDIR=/var/tmp
CFGDIR=/local/repository/etc
SRS_REPO=https://github.com/srsRAN/$SRS_TYPE

if [ -f $TMPDIR/$SRS_TYPE-setup-complete ]; then
    echo "setup already ran; not running again"
    exit 0
fi

install_srsran_common () {
    apt update
    apt install -y \
        cmake \
        iperf3 \
        libfftw3-dev \
        libmbedtls-dev \
        libsctp-dev \
        libzmq3-dev
}

clone_build_install () {
    cd $SRCDIR
    git clone $SRS_REPO
    cd $SRS_TYPE
    git checkout $COMMIT_HASH
    mkdir build
    cd build
    if [ "$SRS_TYPE" = "srsRAN_Project" ]; then
        cmake ../ -DENABLE_EXPORT=ON -DENABLE_ZEROMQ=ON
    else
        cmake ../
    fi
    make -j `nproc`
    make install
    ldconfig
}

install_srsran_4g () {
    install_srsran_common
    apt install -y \
        build-essential \
        libboost-program-options-dev \
        libconfig++-dev

    clone_build_install
    srsran_install_configs.sh service
    cp /local/repository/etc/srsran/* /etc/srsran/
}

install_srsran_project () {
    install_srsran_common
    apt install -y \
        make \
        gcc \
        g++ \
        pkg-config \
        libyaml-cpp-dev \
        libgtest-dev

    clone_build_install
}

install_srsran_gui () {
    apt update
    apt install -y \
        libboost-system-dev \
        libboost-test-dev \
        libboost-thread-dev \
        libqwt-qt5-dev \
        qtbase5-dev

    clone_build_install
}

install_docker () {
    apt-get update
    apt-get install -y ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
}

build_pull_docker_images () {
    cd $SRCDIR/$SRS_TYPE/docker
    docker compose build 5gc metrics-server
    docker compose pull influxdb grafana
}

install_tshark () {
    apt update
    apt install -y software-properties-common
    add-apt-repository -y ppa:wireshark-dev/stable
    echo "wireshark-common wireshark-common/install-setuid boolean false" | debconf-set-selections
    apt update
    apt install -y \
        tshark \
        wireshark
}

if [ "$SRS_TYPE" = "srsRAN_4G" ]; then
    install_srsran_4g
elif [ "$SRS_TYPE" = "srsRAN_Project" ]; then
    install_docker
    install_tshark
    install_srsran_project
    build_pull_docker_images
elif [ "$SRS_TYPE" = "srsGUI" ]; then
    install_srsran_gui
else
    echo "unknown SRS_TYPE: $SRS_TYPE"
    exit 1
fi

touch $TMPDIR/$SRS_TYPE-setup-complete
