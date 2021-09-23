FROM public.ecr.aws/lambda/python:3.8

ADD entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
