({
    appDir: "./",
    baseUrl: "js/lib",
    paths:{
        plugin:'../plugin',
        templates:'../templates'
    },
    shim: {
        underscore: {
            exports: '_'
        }
    },
    modules:[
        {name: '../basic'},
        {name: '../comfortplace'},
        {name: '../comfortplace_backend'}
    ],
    findNestedDependencies: true,
    optimize: "uglify",
    optimizeCss: "standard",
    preserveLicenseComments: false,
    dir: './web-built'
})