#  比较供水管网模型中有水泵与无水泵的区别

## 作者
- 韩朝 北京工业大学 建筑工程学院
- hanzhao@emails.bjut.edu.cn

## 增加水泵的方法
1. 确定固定水头水源数量；Epanet中Reservoir数量；
2. 对R（i），记录正常运行时的供水量Q，以及总水头H;
3. 增加一个dummy node以及一个pump；
4. dummy node代替水源与管网相连接；
5. dummy node和R（i）之间由pump连接；
6. 将水源R（i）的总水头和dummy node 的高程和需水量设置为0；
7. 设置pump服务曲线，采用单点设计方法。设计点Flow= R(i)的供水量Q，Head=R(i)的原水头H;
8. 重复上述2~7步，直到所有固定水头水源修改为由水泵提供水头的水源。

## 文件说明
|文件|说明|
| - | :-: |
|readme.md| 说明文件|
|report-比较供水管网模型有水泵和无水泵的计算结果.pdf|比较结果报告|
|sobol-leakType-post_data_GWSL_pump.mat|平均泄漏面积计算方法的计算结果|
|sobol-leakType-post_data_GWSL_4.mat|根据泄漏类型计算泄漏面积方法的计算结果|
|PumpandNoPump.mlx|展示计算结果的Matlab live script|

## 致谢
- 感谢老师们在支持。
## 时间
- 2019-08-27
