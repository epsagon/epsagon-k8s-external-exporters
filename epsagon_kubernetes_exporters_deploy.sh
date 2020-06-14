#! /bin/bash
function is_positive_answer {
    answer=$1
    if [ ${answer} == 'y' ] ; then
        answer='Y'
    fi
    if [ ${answer} == 'Y' ] ; then
        return 0;
    fi
    return 1;
}


function does_config_file_exist {
    if [ -f ~/.kube/config ]; then
        return 0
    fi
    for i in `echo $KUBECONFIG | tr ':' '\n'`; do
        if [ -f "$i" ]; then
            return 0
        fi
    done
    return 1
}

function fetch_exporter {
    EXPORTER_FILE=$1
    EXPORTER_URL=https://raw.githubusercontent.com/epsagon/epsagon-k8s-external-exporters/master/${EXPORTER_FILE}
    EXPORTER_DIR=$(dirname $EXPORTER_FILE)
    echo "Fetching ${EXPORTER_FILE}"
    if [ -f $EXPORTER_FILE ] ; then
        echo "${EXPORTER_FILE} already exists - using that file"
        return 0
    fi
    if [ ! -d $EXPORTER_DIR ] ; then
        mkdir $EXPORTER_DIR
    fi
    if [ `which wget` ] ; then
        wget -O ${EXPORTER_FILE} $EXPORTER_URL
    else
        if [ `which curl` ] ; then
            curl $EXPORTER_URL -o ${EXPORTER_FILE}
        else
            if [ -s ${EXPORTER_FILE} ] ; then
                echo "Could not get ${EXPORTER_FILE}"
                echo "Please download the exporter from:"
                echo $EXPORTER_URL
                exit 1
            fi
        fi
    fi
}

function install_exporter {
    CONTEXT=$1
    CONFIG=$2
    EXPORTER_FILENAME=$3
    KUBECTL="kubectl --context ${CONTEXT} --kubeconfig=${CONFIG}"
    ${KUBECTL} apply -f ${EXPORTER_FILENAME}
    rm -f ${EXPORTER_FILENAME}
}

function apply_celery_exporter {
    CONTEXT=$1
    CONFIG=$2
    echo 'Please insert the messaging broker url used by your Celery, for example:'
    echo "rabbitmq: amqp://guest:guest@rabbitmq-service.monitoring:5672//"
    echo "redis: redis://redis:6379/"
    echo "URL:"
    read broker_url
    exporter_file=external-metrics-exporters/celery-exporter.yaml
    fetch_exporter ${exporter_file}
    cat ${exporter_file} | sed -e "s|\${CELERY_BROKER_URL}|${broker_url}|g" > celery_exporter.yaml
    install_exporter $CONTEXT $CONFIG "celery_exporter.yaml"
}

function apply_node_exporter {
    CONTEXT=$1
    CONFIG=$2
    exporter_file=external-metrics-exporters/node-exporter.yaml
    fetch_exporter ${exporter_file}
    cp ${exporter_file} ./node_exporter.yaml
    install_exporter $CONTEXT $CONFIG "node_exporter.yaml"
}

function apply_exporters {
    CONTEXT=$1
    CONFIG=$2
    echo -n "Would you like to install celery exporter? [Y/N] "
    read answer
    is_positive_answer $answer
    if [ $? -eq 0 ] ; then
        apply_celery_exporter $CONTEXT $CONFIG
    fi
    echo -n "Would you like to install node exporter? [Y/N] "
    read answer
    is_positive_answer $answer
    if [ $? -eq 0 ] ; then
        apply_node_exporter $CONTEXT $CONFIG
    fi
}

function does_config_file_exist {
    if [ -f ~/.kube/config ]; then
        return 0
    fi
    for i in `echo $KUBECONFIG | tr ':' '\n'`; do
        if [ -f "$i" ]; then
            return 0
        fi
    done
    return 1
}

function install_exporters_on_all_contexts {
    echo "Welcome to Epsagon!"
    config_file_path="${HOME}/.kube/config"
    if [ ! does_config_file_exist ] ; then
        echo "Could not find any config file for kubectl"
        echo 'Please insert your kubectl config file path:'
        read config_file_path
    fi
    for context in `kubectl config get-contexts --no-headers --kubeconfig=${config_file_path} | awk {'gsub(/^\*/, ""); print $1'}`; do
        echo ""
        echo -n "Would you like to install any metrics exporters for: $context ? [Y/N] "
        read answer
        is_positive_answer $answer
        if [ $? -eq 0 ] ; then
            apply_exporters $context $config_file_path
        else
            echo "skipping this cluster"
            continue
        fi
    done
}

install_exporters_on_all_contexts
