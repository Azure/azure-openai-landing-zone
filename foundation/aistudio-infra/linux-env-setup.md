# Setting up a Linux environment

If you are using a Linux environment to deploy this landing zone, follow these steps to setup your environment.  Please note that these commands were used in a specific Ubuntu Linux 22.04.1.  You can easily create a shell script and modify these to fit your own Linux distro.

1. **Update and Install Python**
    ```sh
    $ sudo apt update
    $ sudo apt install python3-pip
    ```

2. **Verify Python Installation**
    ```sh
    $ python3 --version
    Python 3.12.4
    $ pip3 --version
    pip 24.2 from ~/miniconda3/lib/python3.12/site-packages/pip (python 3.12)
    ```

3. **Install Miniconda**
    ```sh
    $ wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
    $ chmod +x Miniconda3-latest-Linux-x86_64.sh
    $ ./Miniconda3-latest-Linux-x86_64.sh
    ```

4. **Verify Miniconda Installation**
    ```sh
    $ conda --version
    conda 24.7.1
    ```

5. **Create Conda Environment and Install Azure CLI**
    ```sh
    $ conda create -n <your-conda-env-name> python=3.10
    $ curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    ```

6. **Verify Azure CLI Installation**
    ```sh
    $ az --version
    azure-cli 2.63.0
    ...
    ```

7. **Install Additional Python Packages**
    ```sh
    $ pip install azure.identity
    $ pip install azure-mgmt-resource
    $ pip install keyring
    $ pip install keyrings.alt
    ```

8. **Verify Python Package Installations**
    ```sh
    $ pip list | grep azure
    azure-common 1.1.28
    azure-core 1.30.2
    azure-identity 1.17.1
    azure-mgmt-core 1.4.0
    azure-mgmt-resource 23.1.1
    azure-monitor-opentelemetry-exporter 1.0.0b28
    ```

9. **Install Promptflow and Verify Installation**
    ```sh
    $ pip install promptflow --upgrade
    $ pf --version
    {
      "promptflow": "1.15.0",
      "promptflow-core": "1.15.0",
      "promptflow-devkit": "1.15.0",
      "promptflow-tracing": "1.15.0"
    }
    ```

10. **Continue with Deployment Steps**
    ```sh
    $ az login
    ```
```
*IMPORTANT*
Make sure you have a network connection to your VNet.