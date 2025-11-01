module.exports = async function (context, req) {
    context.log('Hello function triggered');

    context.res = {
        status: 200,
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            message: "Hello from Azure Functions!",
            timestamp: new Date().toISOString(),
            function: "hello",
            method: req.method,
            url: req.url
        })
    };
};

