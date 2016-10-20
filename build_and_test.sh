#!/bin/sh

# Don't do [set -e] because if
# [docker exec ... cd test && ./run.sh ${*}] fails
# I want the [docker cp] command to extract the coverage info

hash docker 2> /dev/null
if [ $? != 0 ]; then
  echo
  echo "docker is not installed"
  exit 1
fi

# Use 1: ./test.sh
#   Load and run all tests.
# Use 2: ./test.sh 347
#   Load all tests and run those whose hex-id includes 347
#   Use the test file's hex-id prefix to run *all* the tests in that file
#   Use the tests individual hex-id to run just that one test

my_dir="$( cd "$( dirname "${0}" )" && pwd )"

app_dir=/app
docker_version=$(docker --version | awk '{print $3}' | sed '$s/.$//')
client_port=4558
server_port=4557

${my_dir}/base/build-image.sh ${app_dir}
${my_dir}/client/build-image.sh ${app_dir} ${client_port}
${my_dir}/server/build-image.sh ${app_dir} ${docker_version} ${server_port}

if [ $? != 0 ]; then
  echo
  echo "./build.sh FAILED"
  exit 1
fi

export DOCKER_ENGINE_VERSION=${docker_version}
export CLIENT_PORT=${client_port}
export SERVER_PORT=${server_port}
docker-compose down
docker-compose up -d

# - - - - - - - - - - - - - - - - - - - - - - - - - -
# server
server_cid=`docker ps --all --quiet --filter "name=runner_server"`
#docker exec ${server_cid} sh -c "cat Gemfile.lock"
docker exec ${server_cid} sh -c "cd test && ./run.sh ${*}"
server_exit_status=$?
docker cp ${server_cid}:/tmp/coverage ${my_dir}/server
echo "Coverage report copied to ${my_dir}/server/coverage"
cat ${my_dir}/server/coverage/done.txt

# - - - - - - - - - - - - - - - - - - - - - - - - - -
# client
client_cid=`docker ps --all --quiet --filter "name=runner_client"`
docker exec ${client_cid} sh -c "cd test && ./run.sh ${*}"
client_exit_status=$?
docker cp ${client_cid}:/tmp/coverage ${my_dir}/client
# Client Coverage is broken. Simplecov is not seeing the *_test.rb files
#echo "Coverage report copied to ${my_dir}/client/coverage"
#cat ${my_dir}/client/coverage/done.txt

# - - - - - - - - - - - - - - - - - - - - - - - - - -

show_cids() {
  echo
  echo "server: cid = ${server_cid}, exit_status = ${server_exit_status}"
  echo "client: cid = ${client_cid}, exit_status = ${client_exit_status}"
  echo
}

if [ ${client_exit_status} != 0 ]; then
  show_cids
  exit 1
fi
if [ ${server_exit_status} != 0 ]; then
  show_cids
  exit 1
fi

echo
echo "All passed. Removing runner containers..."
docker-compose down 2>/dev/null