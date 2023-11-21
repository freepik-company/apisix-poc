# POC APISIX

This project is a proof of concept of the API Gateway APISIX and how we can use it in our project.

This project will deploy a configurated APISIX gateway with Prometheus and Grafana for metrics. Once deployed the gateway will have routes and users for testing purposes.

The project has a Makefile with all the commands needed to install and run this project.

## Installation and usage

To install and start using this project clone this repository and follow the next steps.

1. **Start the containers** 
    
    With the following command you will build the containers setup needed to run the project.

    ```bash
    make start
    ```
    This will start the containers configure APISIX and create a port-forward to the final API.
2. **Configuration**
    
    The configuration of APISIX Gateway is as follows.
    - **1 Upstream** pointing to the final API.
    - **1 Service** that uses the above upstream and groups the routes with the following plugins:
        - `key-auth` Authentication this means that all the endpoints of this API will require authentication.
        - `proxy-rewrite` To rewrite the final route from `/v1/*` to `/b2b/v1/*`
        - `prometheus` To exports metrics of APISIX.
    - **5 Routes**:
        - Default `/v1/*`
        - Legacy download `/v1/download`
        - Icons download `/v1/icons/*/download`
        - Resources downloads `/v1/resources/*/download`
        - Resource format download `/v1/resources/*/download/*`
    - **2 Consumer groups**
        - Trial. Plugins: 
            - `response-rewrite` Set some headers.
            - `rate-limit` limit the request to 3 every 5 minutes.
        - Premium. Plugins:
            - `response-rewrite` Set some headers.
            - `rate-limit` limit the request to 10 every 5 minutes.
    - **6 Consumers** These are the clients that consume the API:
        - `user1` Belongs to Trial consumer group
        - `user2` Belongs to Trial consumer group
        - `user3` Belongs to Premium consumer group
        - `user4` Belongs to Premium consumer group
        - `no_limit_free` Belongs to Trial consumer group and overwrite the rate-limit to 10000 per 5 minutes 
        - `no_limit_premium` Belongs to Premium consumer group and overwrite the rate-limit to 10000 per 5 minutes
      

3. **Testing**
    
    There are a list of command that will test APISIX through the created routes, users and so on.

    | Command                                | Endpoint                                      | User                       |
    |----------------------------------------|-----------------------------------------------|----------------------------|
    | `make test-free-resources-download`    | Resources download `/v1/resources/*/download` | `user1` Free               |
    | `make test-free-icons-download`        | Icons download `/v1/icons/*/download`         | `user2` Free               |
    | `make test-free-legacy-download`       | Legacy download `/v1/download`        | `no_limit_free` Free       |
    | `make test-premium-resources-download` | Resources download `/v1/resources/*/download`     | `user3` Premium            |
    | `make test-premium-icons-download`     | Icons download `/v1/icons/*/download`         | `user4` Premium            |
    | `make test-premium-legacy-download`    | Legacy download `/v1/download`        | `no_limit_premium` Premium |

    All these commands are prepared to make a request to the specified endpoints using APIKeys that belong to users.

4. **Load benchmarking**

    There is a command to perform a load benchmarking using the `vegeta` tool over all the endpoints created. To run this command write:
    ```bash
    make load
    ```
   
    This command will execute ***8 request per seconds in 30 seconds*** using the real API and the APISIX gateway to compare latency, errors, etc. The result of this command would be like this.

    ```bash
    API Load Test
    Requests      [total, rate, throughput]         240, 8.03, 8.02
    Duration      [total, attack, wait]             29.94s, 29.875s, 65.228ms
    Latencies     [min, mean, 50, 90, 95, 99, max]  59.642ms, 73.542ms, 72.134ms, 83.115ms, 87.305ms, 109.075ms, 115.342ms
    Bytes In      [total, mean]                     232224, 967.60
    Bytes Out     [total, mean]                     0, 0.00
    Success       [ratio]                           100.00%
    Status Codes  [code:count]                      200:240  
    Error Set:
   
    APISIX Load Test
    Requests      [total, rate, throughput]         240, 8.03, 8.01
    Duration      [total, attack, wait]             29.962s, 29.872s, 90.6ms
    Latencies     [min, mean, 50, 90, 95, 99, max]  60.363ms, 75.296ms, 73.544ms, 87.259ms, 91.979ms, 110.878ms, 121.187ms
    Bytes In      [total, mean]                     232224, 967.60
    Bytes Out     [total, mean]                     0, 0.00
    Success       [ratio]                           100.00%
    Status Codes  [code:count]                      200:240  
    Error Set:
    ```
   
    The command also generates two HTML files which contains a graph with the request used. The name of the generated HTML files are: `load_APISIX.html` and `load_API.html`.


5. **Remaining commands**

    The rest of the commands availabe are:
    - **Stop** `make stop` Stop and remove the containers
    - **Restart** `make restart` Performs a stop, start and configure commands
    - **Status** `make status` Show the status of the containers.
    - **Configure** `make configure` Configure APISIX if it's already configured this overwrites the configuration.