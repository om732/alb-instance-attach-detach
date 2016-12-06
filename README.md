alb-instance-attach-detach
===

## Overview
The attach and detach script for EC2 with EC2.

## Usage

```
usage: alb-instance-attach-detach.sh -i [INSTANCE_ID] -n [ALB_NAME] -a [ACTION]
  -i, --instance-id: EC2 Instance Id
  -n, --alb-name   : ALB Name
  -a, --action     : attach or detach
  -h, --help       : Print Help (this message) and exit
```

### Example

attach

```
alb-instance-attach-detach.sh --action attach -n example-alb-name -i i-xxxxxxxxxxxxxxxxx
```

detach

```
alb-instance-attach-detach.sh --action detach -n example-alb-name -i i-xxxxxxxxxxxxxxxxx
```

## Licence

MIT

## Author

[og732](https://github.com/om732)
