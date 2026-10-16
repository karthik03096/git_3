with ran_emp as(
    select 
department_name, employee_name,e.salary, DENSE_RANK()over(PARTITION BY e.dep_id order by e.salary DESC)rnk 
from employee e join dept d on e.dep_id=d.dept_id
)
select department_name, employee_name,salary
from ran_emp
where rnk=2
