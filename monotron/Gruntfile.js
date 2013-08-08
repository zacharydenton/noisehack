// Generated by CoffeeScript 1.6.2
(function() {
  module.exports = function(grunt) {
    grunt.initConfig({
      coffee: {
        compile: {
          files: {
            'js/monotron.js': 'js/monotron.coffee'
          }
        }
      },
      less: {
        compile: {
          files: {
            'css/monotron.css': 'css/monotron.less'
          }
        }
      },
      watch: {
        all: {
          files: ['js/*.coffee', 'css/*.less'],
          tasks: ['coffee', 'less']
        }
      },
      connect: {
        server: {
          options: {
            port: 1337,
            hostname: '*'
          }
        }
      }
    });
    grunt.loadNpmTasks('grunt-contrib-coffee');
    grunt.loadNpmTasks('grunt-contrib-less');
    grunt.loadNpmTasks('grunt-contrib-watch');
    grunt.loadNpmTasks('grunt-contrib-connect');
    return grunt.registerTask('default', ['connect', 'watch']);
  };

}).call(this);