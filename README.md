# Vagrant Export

[Vagrant](http://www.vagrantup.com) plugin to export compressed and optimized linux boxes from virtualbox into a .box file

## Installation

```bash
vagrant plugin install vagrant-export
```

## Useage

```bash
vagrant export
```
Exports the current box into a .box file. The file name is determined by the setting `config.vm.name`, were slashes are replaced with underscores.

So a Vagrantfile with this setting:

```ruby
Vagrant.configure(2) do |config|
	config.vm.name = "hashicorp/precise32"
end
```

will be exported to a file named `hashicorp_precise32.box`

## License

The MIT License (MIT)

Copyright (c) 2015 Georg Großberger

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
