# NKTcontrol
## Matlab controller for NKT's super continuum lasers



This code gives you access to control the NKT SuperK laser and Varia filter directly from Matlab. The code should be self-explanatory, but here is a simple example of it's use (assuming that the matlab file is either in the same folder or in your path):

```
laser = NKTControl
laser.setLowerBandwidth(540)
laser.setUpperBandwidth(560)
laser.setPowerLevel(10)
laser.emissionOn()
```

Please note that the addresses for the laser and Varia are hardcoded towards the end of the file. Furthermore, please consider contributing to this software if you are modifying it (e.g. to use with other hardware).


We take no responsibility of the software and would like to remind everyone to be careful when operating lasers.
