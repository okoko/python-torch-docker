# okoko/python-torch

Base Docker image for python projects needing machine learning framework
[PyTorch](https://pytorch.org/) package.

This image works as a base on which you can install your smaller python
dependencies. PyTorch is rather large package you rather not download
every time your `requirements.txt` changes. If you have many images
using PyTorch, using this as the common base image can save a lot of
disk space.

Your own `requirements.txt` should only contain matching versions of
packages. To know the packages already installed, run

    docker run --rm okoko/python-torch:<tag> pip freeze

The output can be used as content of `--constraint` file to `pip-compile`.

The torch builds for +cuNNN are installed from package index
<https://download.pytorch.org/whl/cuNNN/>. This same index needs to be used to
install `torchvision`. It is not included in the image because it is fairly
small and has dependencies we rather maintain in the images build on this.

# License

The image build is licensed using BSD-3, but the underlying Debian, Python,
PyTorch and any other software have their own licenses. Please take
responsibility and use this image according to licenses of the included
software.
