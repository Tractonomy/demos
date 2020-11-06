FROM ros:foxy-ros-base AS base

ENV ROS_WS /home/ros_ws
WORKDIR ${ROS_WS}
COPY . src/demos/
RUN apt-get update -qq \
    && apt-get dist-upgrade -y \
    && rosdep update \
    && rosdep install --from-paths src --ignore-src -r -y -q \
    # cleanup
    && rm -rf ~/.ros/rosdep/sources.cache \
    && rm -rf /var/lib/apt/lists/*

FROM base as compile-image

# install ros build tools
RUN apt-get update -qq \
    && apt-get install -y -qq \
        python3-colcon-common-extensions \
    && rm -rf /var/lib/apt/lists/*
# source ros and build repo (disable tests to improve build time)
RUN /ros_entrypoint.sh colcon build --cmake-args -DBUILD_TESTING=OFF \
    # remove the src folder for security reasons (does not decrease file size)
    && rm -rf build log src
# append install directory source line to ros_entrypoint.sh
RUN sed -i '/source/a source "${ROS_WS}/install/local_setup.bash"\nexport LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib' /ros_entrypoint.sh

# create multi stage docker setup to decrease the image size
FROM base as runtime-image
# Add Tini
ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini
ENTRYPOINT [ "/tini", "--", "/ros_entrypoint.sh" ]
# append install directory source line to ros_entrypoint.sh
RUN sed -i '/source/a source "${ROS_WS}/install/local_setup.bash"\nexport LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib' /ros_entrypoint.sh
# remove the src folder for security reasons (does not decrease file size)
RUN rm -rf src
COPY --from=compile-image ${ROS_WS}/install ./install
COPY DEFAULT_FASTRTPS_PROFILES.xml .
CMD ["/bin/bash"]