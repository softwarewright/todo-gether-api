import express from 'express';

const app = express();

app.use('/', (req,res)=> {
    res.send({
        health: "ok"
    });
});

export default app;