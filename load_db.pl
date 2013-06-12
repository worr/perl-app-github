use strict;
use warnings;

use Test::MockCommand record => '05_config.db';

`git config --global github.user`;
`git config --global github.pass`;