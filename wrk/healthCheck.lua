wrk.method = "GET"
wrk.headers["Content-Type"] = "application/json"

function request()
    return wrk.format(nil, "/healthCheck")
end