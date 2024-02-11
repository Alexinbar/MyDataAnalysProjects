----q.1

select p.ProductID, p.Name, p.Color, p.ListPrice, p.Size
from Production.Product p left join
	 Sales.SalesOrderDetail sod on p.ProductID = sod.ProductID
where sod.ProductID IS NULL
order by 1


----q.2

select c.CustomerID,
	   ISNULL (p.LastName, 'Unknown'),
	   ISNULL (p.FirstName, 'Unknown')
from Sales.Customer c  left join 
	 Person.Person p on c.CustomerID = p.BusinessEntityID 
where not exists (select *
				  from Sales.SalesOrderHeader s 
				  where c.CustomerID = s.CustomerID)
order by c.CustomerID


----q.3

select top 10 c.CustomerID, p.FirstName, p.LastName, COUNT(s.SalesOrderID) as CountOfOrders
from Sales.Customer c   join 
     Person.Person p on c.PersonID = p.BusinessEntityID join
	 Sales.SalesOrderHeader s on c.CustomerID = s.CustomerID
group by c.CustomerID, p.FirstName, p.LastName
order by  COUNT(s.SalesOrderID) desc, c.CustomerID

----q.4 

select p.FirstName, p.LastName, e.JobTitle, e.HireDate, 
	   COUNT(e.BusinessEntityID) over(partition by e.JobTitle) as CountOfTitle
from HumanResources.Employee e join
	 Person.Person p on e.BusinessEntityID = p.BusinessEntityID


----q.5

select SalesOrderID ,CustomerID, LastName, FirstName, LastOrder, PreviousOrder
from(
     select  o.SalesOrderID, c.CustomerID, p.LastName, p.FirstName, o.OrderDate,
       MAX(OrderDate) over(partition by c.CustomerID) as LastOrder,
	   LAG(o.OrderDate) over(partition by c.CustomerID order by o.OrderDate) as PreviousOrder
     from Sales.SalesOrderHeader o  
     join Sales.Customer c on o.CustomerID = c.CustomerID  
     join Person.Person  p on c.PersonID = p.BusinessEntityID   
	 ) sq
where LastOrder = OrderDate


----q.6

select [Year], SalesOrderID, LastName, FirstName, FORMAT(Total,'#,#.0') as Total
from (
      select *, ROW_NUMBER() over(partition by [Year] order by total desc)  rn
      from (
            select YEAR(OrderDate) as [Year], od.SalesOrderID, p.FirstName, p.LastName,
            SUM(od.LineTotal) over(partition by od.SalesOrderID) as Total
            from Sales.SalesOrderDetail od 
				 join Sales.SalesOrderHeader oh on od.SalesOrderID = oh.SalesOrderID
			     join Sales.Customer c on oh.CustomerID = c.CustomerID
				 join Person.Person p on c.PersonID = p.BusinessEntityID  ) sq1  
	 ) sq2
where rn=1


----q.7

select [Month], [2011],[2012],[2013],[2014]
from (select YEAR(OrderDate) y, MONTH(OrderDate) [Month], SalesOrderID
	  from Sales.SalesOrderHeader) oh
pivot (COUNT(SalesOrderID) for y in ([2011],[2012],[2013],[2014])) p
order by 1


--q.8

with Sum_Price
as (
   select year(modifiedDate) as [Year], month(modifiedDate) as [Month],
          cast(sum(UnitPrice*(1-UnitPriceDiscount)) as decimal(15,2)) as Sum_Price
   from Sales.SalesOrderDetail
   group by year(modifiedDate), month(modifiedDate)
   )
select [Year], cast(month as varchar) as [Month], Sum_Price, 
	  sum(Sum_Price) over (partition by [Year] order by [Month]) as CumSum
from Sum_Price
group by [Year], [Month], Sum_Price
union
select [Year],'grand_total', null, sum(Sum_Price)
from Sum_Price 
group by [Year] 
order by 1,4


--q.9

select *, datediff(d,PreviousEmpHDate,HireDate) as DiffDays
from (
      select *, lag("Employee'sFullName") over (partition by DepartmentName order by HireDate) as PreviousEmpName, 
	            lag(HireDate)over (partition by DepartmentName order by HireDate) as PreviousEmpHDate
      from (
           select d.[Name] as DepartmentName, e.BusinessEntityID as "Employee'sID",
				p.FirstName+' ' +p.LastName as "Employee'sFullName",
				e.HireDate, datediff(m,HireDate,getdate()) as Seniority
		   from Person.Person p
				join HumanResources.Employee e on e.BusinessEntityID = p.BusinessEntityID
				join HumanResources.EmployeeDepartmentHistory dh on dh.BusinessEntityID = e.BusinessEntityID
				join HumanResources.Department d on d.DepartmentID = dh.DepartmentID  
			) x 
	) y
order by DepartmentName, HireDate desc


--q.10a

select HireDate, DepartmentID, 
    string_agg(convert(varchar(10),e.BusinessEntityID)+' '+ LastName+' '+ FirstName,', ') as TeamEmploees
from HumanResources.Employee e
	join HumanResources.EmployeeDepartmentHistory dh on dh.BusinessEntityID = e.BusinessEntityID
	join Person.Person p on e.BusinessEntityID = p.BusinessEntityID
where dh.EndDate is null
group by HireDate, DepartmentID
order by HireDate desc


--q.10b

with 
cte1
as (
  select HireDate, DepartmentID
  from HumanResources.Employee e
	 join HumanResources.EmployeeDepartmentHistory dh on dh.BusinessEntityID = e.BusinessEntityID
  where dh.EndDate is null
    ),
cte2
as (
  select e.BusinessEntityID, LastName, FirstName, HireDate, DepartmentID
  from HumanResources.Employee e
	 join HumanResources.EmployeeDepartmentHistory dh on dh.BusinessEntityID = e.BusinessEntityID
	 join Person.Person p on e.BusinessEntityID = p.BusinessEntityID
  where dh.EndDate is null
   )
select HireDate, DepartmentID, 
     stuff( (select  ', '+convert(varchar(10),BusinessEntityID)+' '+ LastName+' '+ FirstName
            from cte2
            where HireDate=cte1.HireDate and DepartmentID=cte1.DepartmentID
            for xml path('')),1,2,'') as TeamEmploees
from cte1
group by HireDate, DepartmentID
order by HireDate desc
