# OpenFOAM-6 on CentOS 7
# [https://openfoamwiki.net/index.php/Installation/Linux/OpenFOAM-6/CentOS_SL_RHEL#CentOS_7.5_.281804.29]

FROM alpine AS src

# download src & 3rd
RUN apk add git wget && \
    mkdir /opt/OpenFOAM && cd /opt/OpenFOAM && \
    git clone -b version-6 --single-branch --depth 1 https://github.com/OpenFOAM/OpenFOAM-6.git && \
    git clone -b version-6 --single-branch --depth 1 https://github.com/OpenFOAM/ThirdParty-6.git && \
    cd ThirdParty-6 && mkdir download && \
    wget -P download https://www.cmake.org/files/v3.9/cmake-3.9.0.tar.gz && \
    wget -P download https://github.com/CGAL/cgal/releases/download/releases%2FCGAL-4.10/CGAL-4.10.tar.xz && \
    wget -P download https://sourceforge.net/projects/boost/files/boost/1.55.0/boost_1_55_0.tar.bz2 && \
    wget -P download https://www.open-mpi.org/software/ompi/v2.1/downloads/openmpi-2.1.1.tar.bz2 && \
    wget -P download http://www.paraview.org/files/v5.4/ParaView-v5.4.0.tar.gz
RUN apk --update add tar xz && \
    cd /opt/OpenFOAM/ThirdParty-6 && \
    tar -xzf download/cmake-3.9.0.tar.gz && \
    tar -xJf download/CGAL-4.10.tar.xz && \
    tar -xjf download/boost_1_55_0.tar.bz2 && \
    tar -xjf download/openmpi-2.1.1.tar.bz2 && \
    tar -xzf download/ParaView-v5.4.0.tar.gz --transform='s/ParaView-v5.4.0/ParaView-5.4.0/' && \
    cd .. && \
    sed -i -e 's/\(boost_version=\)boost-system/\1boost_1_55_0/' OpenFOAM-6/etc/config.sh/CGAL && \
    sed -i -e 's/\(cgal_version=\)cgal-system/\1CGAL-4.10/' OpenFOAM-6/etc/config.sh/CGAL


FROM centos:centos7.6.1810 as build

RUN yum install -y epel-release && \
    yum groupinstall -y 'Development tools' && \
    yum install -y zlib-devel libXext-devel libGLU-devel libXt-devel libXrender-devel libXinerama-devel \
        libpng-devel libXrandr-devel libXi-devel libXft-devel libjpeg-turbo-devel libXcursor-devel \
        readline-devel ncurses-devel python python-devel qt-devel qt-assistant \
        mpfr-devel gmp-devel wget which munge-libs \
        libpsm2-devel libibverbs-devel && \
    yum clean all

# copy src & 3rd
COPY --from=src /opt/OpenFOAM /opt/OpenFOAM

# build 3rd
RUN /bin/bash -c 'source /opt/OpenFOAM/OpenFOAM-6/etc/bashrc WM_LABEL_SIZE=64 WM_MPLIB=OPENMPI FOAMY_HEX_MESH=yes && \
        cd $WM_THIRD_PARTY_DIR && \
        ./makeCmake > log.makeCmake 2>&1 && wmRefresh && \
        ./Allwmake > log.make 2>&1 && wmRefresh && \
        ./makeParaView -mpi -python -qmake $(which qmake-qt4) > log.makePV 2>&1 && wmRefresh'

# build of
RUN /bin/bash -c 'source /opt/OpenFOAM/OpenFOAM-6/etc/bashrc WM_LABEL_SIZE=64 WM_MPLIB=OPENMPI FOAMY_HEX_MESH=yes && \
        cd $WM_PROJECT_DIR && \
        ./Allwmake -j $(nproc) > log.make 2>&1 && wmRefresh'

