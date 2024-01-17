#!/bin/sh
gimp -i -b '(gauss-blur "*.png" 10.0)' -b '(gimp-quit 0)'
