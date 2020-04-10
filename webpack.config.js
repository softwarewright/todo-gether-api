const path = require('path');

module.exports = {
    mode: 'development',
    entry: './src/index.ts',
    target: "node",
    output: {
        libraryTarget: 'commonjs2',
        filename: 'index.js',
        path: path.resolve(__dirname, 'dist')
    },
    devtool: 'source-map',
    module: {
        rules: [
            { test: /\.ts$/, use: 'ts-loader', exclude: /node_modules/ },
        ]
    },
    resolve: {
        extensions: ['.ts', '.js']
    }
}